require File.join(File.dirname(__FILE__),'constants')

module Rod
  class Service
    # Closes the database.
    def self.close(handler)
      _close(handler) 
    end

    def self.model_struct_name(path)
      "model_" + path.gsub(/\W/,"_").squeeze("_")
    end

    def self.init_structs(classes)
      last_struct = nil
      classes.map do |klass, count|
        offset = 
          if last_struct 
            "|  model_p->#{klass.struct_name}_offset = " + 
              "model_p->#{last_struct}_offset + " +
              "model_p->#{last_struct}_size;\n|\n"
          else
            # leav one segment for stats
            "|  model_p->#{klass.struct_name}_offset = page_size;\n"
          end
        last_struct = klass.struct_name
        size = <<-END
        |  model_p->#{klass.struct_name}_size =  
        |    (sizeof(#{klass.struct_name}) * #{count} / page_size) * page_size + 
        |    (sizeof(#{klass.struct_name}) * #{count} % page_size == 0 ? 0 : page_size);
        END
        count = "|  model_p->#{klass.struct_name}_count = #{count};\n|\n"
        offset + size + count
      end.join("\n").margin
    end

    def self.generate_c_code(path, classes)
      unless @code_generated
        inline(:C) do |builder|
          builder.include '<stdlib.h>'
          builder.include '<stdio.h>'
          builder.include '<string.h>'
          builder.include '<fcntl.h>'
          builder.include '<unistd.h>'
          builder.include '<sys/mman.h>'
          classes.each do |klass, count|
            builder.prefix(klass.typedef_struct)
          end

          model_struct = model_struct_name(path);
          str = <<-END
            |typedef struct {
            |#{classes.map do |klass, count|
                substruct = <<-SUBEND
                |  #{klass.struct_name} * #{klass.struct_name}_table;
                |  unsigned long last_#{klass.struct_name};
                |  unsigned long #{klass.struct_name}_offset;
                |  unsigned long #{klass.struct_name}_size;
                |  unsigned long #{klass.struct_name}_count;
                SUBEND
                substruct.margin
              end.join("\n")}
            |  int lib_file;
            |} #{model_struct};
          END
          builder.prefix(str.margin)

          str = <<-END
           |VALUE _create(char * path){
           |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
           |  #{model_struct} * model_p;
           |  model_p = ALLOC(#{model_struct});
           |
           |  #{init_structs(classes)}
           |
           |//prepare the file
           |  char* empty = calloc(page_size,1);
           |  int index;
           |  VALUE cException = #{EXCEPTION_CLASS};
           |  model_p->lib_file = open(path, O_RDWR);
           |  if(model_p->lib_file == -1) {
           |    rb_raise(cException,"Could not open file %s for writing.",path); 
           |  }
           |  \n#{classes.map do |klass, count|
              <<-SUBEND
              |  if(write(model_p->lib_file,
              |    &(model_p->#{klass.struct_name}_count),
              |    sizeof(unsigned long)) == -1){
              |    rb_raise(cException,"Could not write #{klass.struct_name} count.");
              |  }\n
              SUBEND
           end.join("\n")}
           |  if(write(model_p->lib_file,empty,page_size-#{classes.size} * 
           |    sizeof(unsigned long)) == -1){
           |    rb_raise(cException,"Could not fill stats with empty data.");
           |  }
           |
           |  unsigned long file_size = page_size + \n#{classes.map do |klass,count|
          "|    model_p->#{klass.struct_name}_size "
           end.join("+\n")};
           |  for(index = 1; index < file_size / page_size;index++){
           |    if(write(model_p->lib_file, empty, page_size) == -1){
           |      rb_raise(cException,"Could not fill data space with empty data.");
           |    }
           |  }
           |  
           |//mmap the structures
           |  \n#{classes.map do |klass, count|
             <<-SUBEND
             |  model_p->#{klass.struct_name}_table = mmap(NULL, 
             |    model_p->#{klass.struct_name}_size, PROT_WRITE | PROT_READ,
             |    MAP_SHARED, model_p->lib_file, 
             |    model_p->#{klass.struct_name}_offset);
             |  model_p->last_#{klass.struct_name} = 0;
             SUBEND
           end.join("\n")}
           |    
           |   
           |//create the wrapping object
           |  VALUE cClass = rb_define_class("#{model_struct_name(path).camelcase(true)}",
           |    rb_cObject);
           |  return Data_Wrap_Struct(cClass, 0, free, model_p);
           |}
          END
          builder.c_singleton(str.margin)

          str =<<-END
          |VALUE _join_indices(unsigned long offset, unsigned long count, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  _join_element * element_p = model_p->_join_element_table + offset;
          |  unsigned long index;
          |  VALUE result = rb_ary_new();
          |  for(index = 0; index < count; index++, element_p++){
          |    rb_ary_push(result,INT2NUM(element_p->offset));
          |  }
          |  return result;
          |}
          END
          builder.c_singleton(str.margin)

          str =<<-END
          |void _set_join_element_offset(unsigned long element_offset,
          |  unsigned long element_index, unsigned long offset, 
          |  VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  _join_element * element = model_p->_join_element_table +
          |    element_offset + element_index;
          |  if(element->index != element_index){
          |      VALUE eClass = rb_const_get(rb_cObject, rb_intern("Exception"));
          |      rb_raise(eClass, "#{name} element index is not consistant: %lu %lu!",
          |        element_index, element->index);
          |  } 
          |  element->offset = offset;
          |}
          END
          builder.c_singleton(str.margin)

          classes.each do |klass,count|
            next if klass == ::Rod::JoinElement
            str =<<-END
            |void _store_#{klass.struct_name}(VALUE object, VALUE handler){
            |  #{model_struct} * model_p;
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  #{klass.struct_name} * struct_p = model_p->#{klass.struct_name}_table +
            |    model_p->last_#{klass.struct_name}++;
            |  \n#{klass.fields.map do |field, type|
               raise "TODO implement" if type == :string
               if field == "rod_id"
                 # the number is incresed by 1, because 0 indicates that the 
                 # (refered) object is nil
                 "|  struct_p->rod_id = model_p->last_#{klass.struct_name};"
               else
                 "|  struct_p->#{field} = #{RUBY_TO_C_MAPPING[type]}(rb_funcall(object, rb_intern(\"#{field}\"),0));"
               end
            end.join("\n")}
            |  \n#{klass.singular_associations.map do |name, options|
              <<-SUBEND
              |  VALUE referenced_#{name} = rb_funcall(object, rb_intern("#{name}"),0);
              |  if(referenced_#{name} == Qnil){
              |    struct_p->#{name} = 0;
              |  } else {
              |    struct_p->#{name} = NUM2ULONG(rb_funcall(referenced_#{name}, rb_intern("rod_id"),0));
              |  }
              SUBEND
            end.join("\n")}
            |  \n#{klass.plural_associations.map do |name, options|
              <<-SUBEND
              |  VALUE referenced_#{name} = rb_funcall(object, rb_intern("#{name}"),0);
              |  struct_p->#{name}_offset = model_p->last__join_element;
              |  if(referenced_#{name} == Qnil){
              |    struct_p->#{name}_count = 0;
              |  } else {
              |    VALUE aClass = rb_const_get(rb_cObject, rb_intern("Array"));
              |    if(!rb_obj_is_kind_of(referenced_#{name},aClass)){
              |      VALUE eClass = rb_const_get(rb_cObject, rb_intern("Exception"));
              |      rb_raise(eClass, "#{name} doesn't return an instance of Array");
              |    }
              |    _join_element * element;
              |    unsigned long size = NUM2ULONG(rb_funcall(referenced_#{name},rb_intern("size"),0));
              |    struct_p->#{name}_count = size;
              |    unsigned long index;
              |    for(index = 0; index < size; index++){
              |      element = model_p->_join_element_table + 
              |        model_p->last__join_element++;
              |      element->offset = NUM2ULONG(rb_funcall(rb_ary_entry(referenced_#{name},index),
              |        rb_intern("rod_id"),0));
              |      element->index = index;
              |    } 
              |  }
              SUBEND
            end.join("\n")}
            |  VALUE sClass = rb_funcall(object, rb_intern("class"),0);
            |  rb_iv_set(object,"@struct",Data_Wrap_Struct(sClass, 0, 0, struct_p));
            |}
            END
            builder.c_singleton(str.margin)
          end

          str =<<-END
          |void _close(VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  VALUE cException = #{EXCEPTION_CLASS};
          |  \n#{classes.map do |klass, count|
               <<-SUBEND
               |  if(munmap(model_p->#{klass.struct_name}_table,
               |    model_p->#{klass.struct_name}_size) == -1){
               |    rb_raise(cException,"Could not unmap #{klass.struct_name}."); 
               |  }
               SUBEND
          end.join("\n")}
          |  if(close(model_p->lib_file) == -1){
          |    rb_raise(cException,"Could not close model file."); 
          |  }
          |}
          END
          builder.c_singleton(str.margin)

          str =<<-END
          |VALUE _open(char * path){
          |  #{model_struct} * model_p;
          |  int lib_file = open(path, O_RDONLY);
          |  VALUE cException = #{EXCEPTION_CLASS};
          |  if(lib_file == -1) {
          |    rb_raise(cException,"Could not open data file %s for reading.",path); 
          |  }
          |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
          |  model_p = ALLOC(#{model_struct});
          |
          |  \n#{last_struct = nil
          classes.map do |klass, count|
             <<-SUBEND
             |  unsigned long #{klass.struct_name}_count;
             |  if(read(lib_file, &#{klass.struct_name}_count, sizeof(unsigned long)) == -1){
             |    rb_raise(cException,"Could not read #{klass.struct_name} count."); 
             |  }
             #{offset = 
               if last_struct 
                 "|  model_p->#{klass.struct_name}_offset = " + 
                   "model_p->#{last_struct}_offset + " +
                   "model_p->#{last_struct}_size;\n|\n"
               else
                 # leav one segment for stats
                 "|  model_p->#{klass.struct_name}_offset = page_size;\n"
               end
             last_struct = klass.struct_name
             offset}
             |  model_p->#{klass.struct_name}_size =  
             |    (sizeof(#{klass.struct_name}) * #{klass.struct_name}_count / page_size) 
             |      * page_size + 
             |    (sizeof(#{klass.struct_name}) * #{klass.struct_name}_count % page_size == 
             |      0 ? 0 : page_size);
             | 
             |  model_p->#{klass.struct_name}_count = #{klass.struct_name}_count;
             |
             |  model_p->#{klass.struct_name}_table = mmap(NULL, 
             |    model_p->#{klass.struct_name}_size, PROT_READ, MAP_SHARED, 
             |    lib_file, model_p->#{klass.struct_name}_offset);
             |  model_p->last_#{klass.struct_name} = #{klass.struct_name}_count; 
             SUBEND
          end.join("\n")}
          |  model_p->lib_file = lib_file;
          |//create the wrapping object
          |  VALUE cClass = rb_define_class("#{model_struct_name(path).camelcase(true)}",
          |    rb_cObject);
          |  return Data_Wrap_Struct(cClass, 0, free, model_p);
          |}
          END
          builder.c_singleton(str.margin)

          classes.each do |klass, count|
            next if klass == ::Rod::JoinElement
            str = <<-END
            |unsigned long _#{klass.struct_name}_count(VALUE handler){
            |  #{model_struct} * model_p;
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  return model_p->#{klass.struct_name}_count;
            |}
            END
            builder.c_singleton(str.margin)

            str = <<-END
            |VALUE _#{klass.struct_name}_get(VALUE handler, unsigned long index){
            |  #{model_struct} * model_p;
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  VALUE cClass = rb_define_class("#{klass.struct_class_name}",rb_cObject);
            |  return Data_Wrap_Struct(cClass,0,0,
            |    model_p->#{klass.struct_name}_table + index);
            |}
            END
            builder.c_singleton(str.margin)

            # This method is created to force rebuild of the C code, since
            # it is rebuild on the basis of methods' signatures change.
            builder.c_singleton("void __unused_method_#{rand(1000)}(){}")
          end
        end
      end
      @code_generated = true
    end
  end
end
