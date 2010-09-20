require File.join(File.dirname(__FILE__),'constants')

module Rod
  class Service
    # Closes the database.
    def self.close(handler, classes)
      _close(handler, classes) 
    end

    ## Helper methods printing some generated code ##

    def self.model_struct_name(path)
      "model_" + path.gsub(/\W/,"_").squeeze("_")
    end

    def self.print_layout(handler)
      self._print_layout(handler)
    end

    def self.init_structs(classes)
      classes.map do |klass|
        <<-END
        |  // first page offset - during READ
        |  // number of pages - during WRITE
        |  model_p->#{klass.struct_name}_offset = 0;
        |
        |  // maximal number of structures on one page
        |  model_p->#{klass.struct_name}_size = page_size / sizeof(#{klass.struct_name});
        |
        |  // the number of allready stored structures
        |  model_p->#{klass.struct_name}_count = 0;
        |
        |  // initialize the tables with NULL to forbid unmapping
        |  model_p->#{klass.struct_name}_table = NULL;

        |  // initialize the last element end
        |  model_p->last_#{klass.struct_name} = 0;
        |
        |  // initialize the file descriptor to -1 to force its creation
        |  model_p->#{klass.struct_name}_lib_file = -1;
        END
      end.join("\n").margin
    end

    def self.size_of_page(klass)
      if klass != ::Rod::StringElement
        "per_page * sizeof(#{klass.struct_name})"
      else
        "page_size"
      end
    end

    # Mmaps the class to its page during database creation.
    # TODO merge with extend data file
    def self.mmap_class(klass)
      str =<<-SUBEND
      |  //printf("mmaping #{klass}\\n");
      |  //unmap the segment(s) first
      |  if(model_p->#{klass.struct_name}_table != NULL){
      |    if(munmap(model_p->#{klass.struct_name}_table,
      |      page_size*(model_p->#{klass.struct_name}_offset)) == -1){
      |      perror(NULL);
      |      VALUE cException = #{EXCEPTION_CLASS};
      |      rb_raise(cException,"Could not unmap segment for #{klass.struct_name}.");
      |    }
      |  }
      |
      |  // increase the segments count by 1
      |  model_p->#{klass.struct_name}_offset++;
      |
      |  // create the file unless it exists
      |  if(model_p->#{klass.struct_name}_lib_file == -1){
      |    char * path = malloc(sizeof(char) * (strlen(model_p->path) +
      |      #{klass.struct_name.size} + 2));
      |    strcpy(path,model_p->path);
      |    strcat(path,".#{klass.struct_name}");
      |    model_p->#{klass.struct_name}_lib_file =
      |      open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
      |    if(model_p->lib_file == -1) {
      |      VALUE cException = #{EXCEPTION_CLASS};
      |      rb_raise(cException,"Could not open file %s for writing.",path);
      |    }
      |    free(path);
      |  }
      |
      |  // exted the file
      |  FILE * #{klass.struct_name}_file =
      |    fdopen(model_p->#{klass.struct_name}_lib_file,"w+");
      |  if(#{klass.struct_name}_file == NULL){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not open file for #{klass.struct_name}.");
      |  }
      |  if(fseek(#{klass.struct_name}_file,0,SEEK_END) == -1){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not seek to end file for #{klass.struct_name}.");
      |  }
      |  char* #{klass.struct_name}_empty_data = calloc(page_size,1);
      |  if(write(model_p->#{klass.struct_name}_lib_file,#{klass.struct_name}_empty_data,
      |    page_size) == -1){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not write to file for #{klass.struct_name}.");
      |  }
      |  if(fseek(#{klass.struct_name}_file,0,SEEK_SET) == -1){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not seek to start file for #{klass.struct_name}.");
      |  }
      |  model_p->#{klass.struct_name}_table = mmap(NULL,
      |    model_p->#{klass.struct_name}_offset * page_size,
      |    PROT_WRITE | PROT_READ, MAP_SHARED, model_p->#{klass.struct_name}_lib_file,0);
      |  if(model_p->#{klass.struct_name}_table == MAP_FAILED){
      |    perror(NULL);
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not mmap segment for #{klass.struct_name}.");
      |  }
      |
      |  // reset the elements counter
      |  #{klass != Rod::StringElement ? "model_p->last_#{klass.struct_name} = 0;" : ""}
      |  // reset cache
      |  VALUE module_#{klass.struct_name} = rb_const_get(rb_cObject, rb_intern("Kernel"));
      |  \n#{klass.name.split("::")[0..-2].map do |mod_name|
        "  module_#{klass.struct_name} = rb_const_get(module_#{klass.struct_name}, " +
          "rb_intern(\"#{mod_name}\"));"
      end.join("\n")}
      SUBEND
      str.margin
    end

    # Generates the code in C responsible for management of the database.
    def self.generate_c_code(path, classes)
      unless @code_generated
        inline(:C) do |builder|
          builder.include '<stdlib.h>'
          builder.include '<stdio.h>'
          builder.include '<string.h>'
          builder.include '<fcntl.h>'
          builder.include '<unistd.h>'
          builder.include '<errno.h>'
          builder.include '<sys/mman.h>'
          classes.each do |klass|
            builder.prefix(klass.typedef_struct)
          end

          model_struct = model_struct_name(path);
          str = <<-END
            |typedef struct {
            |#{classes.map do |klass|
              substruct = <<-SUBEND
              |  #{klass.struct_name} * #{klass.struct_name}_table;
              |  unsigned long last_#{klass.struct_name};
              |  unsigned long #{klass.struct_name}_offset;
              |  unsigned long #{klass.struct_name}_size;
              |  unsigned long #{klass.struct_name}_count;
              |  int #{klass.struct_name}_lib_file;
              SUBEND
              indices = 
                klass.fields.map do |field,options|
                  if options[:index]
                    str =<<-SUBEND
                    |  unsigned long #{klass.struct_name}_#{field}_index_length;
                    |  unsigned long #{klass.struct_name}_#{field}_index_offset;
                    |  unsigned long #{klass.struct_name}_#{field}_index_page;
                    SUBEND
                  end
                end.join("\n")
              (substruct + indices).margin
            end.join("\n")}
            |  // number of pages of join elements
            |  unsigned long _elements_pages_count;
            |
            |  // the handler to the file containing the data
            |  int lib_file;
            |  char * path;
            |
            |  // the offset of the last page
            |} #{model_struct};
          END
          builder.prefix(str.margin)

          str = <<-END
           |VALUE _create(char * path){
           |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
           |  #{model_struct} * model_p;
           |  model_p = ALLOC(#{model_struct});
           |
           |  //join elements
           |  model_p->_elements_pages_count = 1;
           |
           |  #{init_structs(classes)}
           |  model_p->#{StringElement.struct_name}_size = 0;
           |
           |//prepare the file
           |  char* empty = calloc(page_size,1);
           |  VALUE cException = #{EXCEPTION_CLASS};
           |  model_p->path = malloc(sizeof(char)*(strlen(path)+1));
           |  strcpy(model_p->path,path);
           |
           |  model_p->lib_file = open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
           |  if(model_p->lib_file == -1) {
           |    rb_raise(cException,"Could not open file %s for writing.",path);
           |  }
           |
           |  if(write(model_p->lib_file,empty,page_size) == -1){
           |    rb_raise(cException,"Could not fill stats with empty data.");
           |  }
           |
           |  //mmap the structures
           |  \n#{classes.map{|klass| mmap_class(klass)}.join("\n|\n")}
           |
           |//create the wrapping object
           |  VALUE cClass = rb_define_class("#{model_struct_name(path).camelcase(true)}",
           |    rb_cObject);
           |  return Data_Wrap_Struct(cClass, 0, free, model_p);
           |}
          END
          builder.c_singleton(str.margin)

          str =<<-END
          |VALUE _join_indices(unsigned long element_offset, unsigned long count, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  _join_element * element_p;
          |  unsigned long element_index;
          |  VALUE result = rb_ary_new();
          |  for(element_index = 0; element_index < count; element_index++){
          |    element_p = model_p->_join_element_table + element_offset + element_index;
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
          |  _join_element * element_p;
          |  element_p = model_p->_join_element_table + element_offset + element_index;
          |  if(element_p->index != element_index){
          |      VALUE eClass = rb_const_get(rb_cObject, rb_intern("Exception"));
          |      rb_raise(eClass, "Join element indices are inconsistent: %lu %lu!",
          |        element_index, element_p->index);
          |  }
          |  element_p->offset = offset;
          |}
          END
          builder.c_singleton(str.margin)

          str =<<-END
          |VALUE _read_string(unsigned long length, unsigned long offset,
          |  unsigned long page, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
          |  char * str = model_p->#{StringElement.struct_name}_table +
          |    page * page_size + offset;
          |  return rb_str_new(str, length);
          |}
          END
          builder.c_singleton(str.margin)

          str =<<-END
          |VALUE _set_string(VALUE ruby_value, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
          |  unsigned long length = RSTRING_LEN(ruby_value);
          |  char * value = RSTRING_PTR(ruby_value);
          |  unsigned long offset, page, current_page;
          |  char * dest;
          |  // table:
          |  // - first page
          |  // last:
          |  // - during write - first free byte in current page
          |  // offset:
          |  // - during write - number of pages
          |  // - during read - offset in file
          |  // size:
          |  // - during write - number of pages - 1 (?)
          |  // count:
          |  // - total number of bytes
          |  long length_left = length;
          |  offset = model_p->last_#{StringElement.struct_name};
          |  page = model_p->#{StringElement.struct_name}_size;
          |  current_page = page;
          |  while(length_left > 0){
          |    if(length_left + model_p->last_#{StringElement.struct_name} > page_size){
          |      \n#{mmap_class(StringElement)}
          |      model_p->#{StringElement.struct_name}_size++;
          |    }
          |    dest = model_p->#{StringElement.struct_name}_table +
          |      current_page * page_size + offset;
          |    if(length_left > page_size){
          |      memcpy(dest,value,page_size);
          |    } else {
          |      memcpy(dest,value,length_left);
          |    }
          |    value += page_size;
          |    current_page++;
          |    length_left -= page_size;
          |  }
          |
          |  model_p->last_#{StringElement.struct_name} =
          |    (length + 1 + model_p->last_#{StringElement.struct_name}) % page_size;
          |  model_p->#{StringElement.struct_name}_count += length + 1;
          |
          |  VALUE result = rb_ary_new();
          |  rb_ary_push(result, INT2NUM(length));
          |  rb_ary_push(result, INT2NUM(offset));
          |  rb_ary_push(result, INT2NUM(page));
          |  return result;
          |}
          END
          builder.c_singleton(str.margin)

          classes.each do |klass|
            next if klass == JoinElement or klass == StringElement
            klass.fields.each do |field,options|
              next unless options[:index]
              %w{length offset page}.each do |type|
                str =<<-END
                |unsigned long _read_#{klass.struct_name}_#{field}_index_#{type}(VALUE handler){
                |  #{model_struct} * model_p;
                |  Data_Get_Struct(handler,#{model_struct},model_p);
                |  return model_p->#{klass.struct_name}_#{field}_index_#{type};
                |}
                END
                builder.c_singleton(str.margin)
              end
            end
          end

          classes.each do |klass|
            next if klass == JoinElement or klass == StringElement
            str =<<-END
            |// Store the object in the database.
            |// The value returned is the index of the page
            |VALUE _store_#{klass.struct_name}(VALUE object, VALUE handler){
            |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
            |
            |  #{model_struct} * model_p;
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  if((model_p->#{klass.struct_name}_count+1) * sizeof(#{klass.struct_name}) >=
            |    model_p->#{klass.struct_name}_offset * page_size){
            |     \n#{mmap_class(klass)}
            |  }
            |  VALUE result = INT2NUM(model_p->#{klass.struct_name}_offset - 1);
            |  #{klass.struct_name} * struct_p = model_p->#{klass.struct_name}_table +
            |    model_p->#{klass.struct_name}_count;
            |  //printf("struct assigned\\n");
            |  model_p->#{klass.struct_name}_count++;
            |  VALUE sClass = rb_funcall(object, rb_intern("class"),0);
            |  VALUE struct_object = Data_Wrap_Struct(sClass, 0, 0, struct_p);
            |
            |  //printf("fields\\n");
            |  \n#{klass.fields.map do |field, options|
               if field == "rod_id"
                 # the number is incresed by 1, because 0 indicates that the 
                 # (refered) object is nil
                 <<-SUBEND
                 |  struct_p->rod_id = model_p->#{klass.struct_name}_count;
                 |  rb_iv_set(object, \"@rod_id\",INT2NUM(struct_p->rod_id));
                 SUBEND
               elsif options[:type] == :string
                 <<-SUBEND
                 |  VALUE #{field}_string_data = rb_funcall(self,rb_intern("_set_string"),2,
                 |    rb_funcall(object,rb_intern("#{field}"),0), handler);
                 |  struct_p->#{field}_length = NUM2ULONG(rb_ary_entry(#{field}_string_data,0));
                 |  struct_p->#{field}_offset = NUM2ULONG(rb_ary_entry(#{field}_string_data,1));
                 |  struct_p->#{field}_page = NUM2ULONG(rb_ary_entry(#{field}_string_data,2));
                 SUBEND
               else
                 "|  struct_p->#{field} = #{RUBY_TO_C_MAPPING[options[:type]]}("+
                   "rb_funcall(object, rb_intern(\"#{field}\"),0));"
               end
            end.join("\n")}
            |  //printf("singular assocs\\n");
            |  \n#{klass.singular_associations.map do |name, options|
              <<-SUBEND
              |  VALUE referenced_#{name} = rb_funcall(object, rb_intern("#{name}"),0);
              |  if(referenced_#{name} == Qnil){
              |    struct_p->#{name} = 0;
              |  } else {
              |    struct_p->#{name} = NUM2ULONG(rb_funcall(referenced_#{name}, 
              |      rb_intern("rod_id"),0));
              |  }
              SUBEND
            end.join("\n")}
            |  \n#{klass.plural_associations.map do |name, options|
              <<-SUBEND
              |  VALUE referenced_#{name} = rb_funcall(object, rb_intern("#{name}"),0);
              |  struct_p->#{name}_offset = model_p->_join_element_count;
              |  if(referenced_#{name} == Qnil){
              |    struct_p->#{name}_count = 0;
              |  } else {
              |    VALUE aClass = rb_const_get(rb_cObject, rb_intern("Array"));
              |    if(!rb_obj_is_kind_of(referenced_#{name},aClass)){
              |      VALUE eClass = #{EXCEPTION_CLASS};
              |      rb_raise(eClass, "#{name} returns object of invalid type (not Array)");
              |    }
              |    _join_element * element;
              |    unsigned long size = NUM2ULONG(rb_funcall(referenced_#{name},
              |      rb_intern("size"),0));
              |    struct_p->#{name}_count = size;
              |    unsigned long index;
              |    for(index = 0; index < size; index++){
              |      if(model_p->_join_element_count * sizeof(_join_element) >=
              |        page_size * model_p->_join_element_offset){
              |        \n#{mmap_class(JoinElement)}
              |      }
              |      element = model_p->_join_element_table + model_p->_join_element_count;
              |      model_p->_join_element_count++;
              |      element->offset = NUM2ULONG(rb_funcall(rb_ary_entry(referenced_#{name},index),
              |        rb_intern("rod_id"),0));
              |      element->index = index;
              |    }
              |  }
              SUBEND
            end.join("\n")}
            |  rb_iv_set(object,"@struct",struct_object);
            |  return result;
            |}
            END
            builder.c_singleton(str.margin)
          end

          str =<<-END
          |void _close(VALUE handler, VALUE classes){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  VALUE cException = #{EXCEPTION_CLASS};
          |  VALUE klass;
          |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
          |
          |  if(classes != Qnil){
          |  \n#{classes.map.with_index do |klass,index|
            <<-SUBEND
            |    klass = rb_ary_entry(classes, #{index});
            |    // store indices
            |    \n#{klass.fields.map do |field, options|
              if options[:index]
                str =<<-SUBSUBEND
                |    VALUE index_#{klass.struct_name}_#{field} =
                |      rb_funcall(klass,rb_intern("field_index"),1,rb_str_new2("#{field}"));
                |    VALUE index_data_#{klass.struct_name}_#{field} =
                |      rb_funcall(self,rb_intern("_set_string"),2,
                |      index_#{klass.struct_name}_#{field},handler);
                |    model_p->#{klass.struct_name}_#{field}_index_length =
                |      NUM2ULONG(rb_ary_entry(index_data_#{klass.struct_name}_#{field},0));
                |    model_p->#{klass.struct_name}_#{field}_index_offset =
                |      NUM2ULONG(rb_ary_entry(index_data_#{klass.struct_name}_#{field},1));
                |    model_p->#{klass.struct_name}_#{field}_index_page =
                |      NUM2ULONG(rb_ary_entry(index_data_#{klass.struct_name}_#{field},2));
                SUBSUBEND
              end
            end.join("\n|\n")}
            SUBEND
          end.join("\n|\n")}
          |  }
          |  \n#{classes.map do |klass|
            <<-SUBEND
            |  if(model_p->#{klass.struct_name}_table != NULL){
            |    if(munmap(model_p->#{klass.struct_name}_table,page_size) == -1){
            |      rb_raise(cException,"Could not unmap #{klass.struct_name}.");
            |    }
            |  }
            SUBEND
          end.join("\n")}
          |  if(classes != Qnil){
          |    FILE * main_file, * class_file;
          |    unsigned long index;
          |    unsigned long last_offset = 1;
          |    unsigned long new_offset;
          |    char * buffer, * cmd;
          |    //we have concatenate files
          |    main_file = fdopen(model_p->lib_file,"w+");
          |    buffer = malloc(sizeof(char)*page_size);
          |    if(main_file == NULL){
          |      rb_raise(cException,"Could not open file while closing DB.");
          |    }
          |    \n#{classes.map.with_index do |klass, i|
          <<-SUBEND
          |    class_file = fdopen(model_p->#{klass.struct_name}_lib_file,"w+");
          |    if(class_file == NULL){
          |      rb_raise(cException,"Could not open file for #{klass} while closing DB.");
          |    }
          |    if(fseek(class_file,0,SEEK_SET) == -1){
          |      rb_raise(cException,"Could not seek file for #{klass} while copying pages");
          |    }
          |    for(index = 0; index < model_p->#{klass.struct_name}_offset;index++){
          |      if(read(model_p->#{klass.struct_name}_lib_file,buffer,page_size) == -1){
          |        rb_raise(cException,"Could not read file for #{klass}");
          |      }
          |      if(write(model_p->lib_file,buffer,page_size) == -1){
          |        rb_raise(cException,"Could not write to main file for #{klass}");
          |      }
          |    }
          |    // update offset
          |    new_offset = last_offset + model_p->#{klass.struct_name}_offset;
          |    model_p->#{klass.struct_name}_offset = last_offset * page_size;
          |    last_offset = new_offset;
          |    fclose(class_file); //TODO delete this file
          |    cmd = malloc(sizeof(char) * (strlen(model_p->path) +
          |      #{klass.struct_name.size} + 8));
          |    strcpy(cmd,"rm -f ");
          |    strcat(cmd,model_p->path);
          |    strcat(cmd,".#{klass.struct_name}");
          |    if(system(cmd) == -1){
          |      // dont raise exception, since it is not a major bug
          |      perror(NULL);
          |    }
          SUBEND
          end.join("\n")}
          |  free(buffer);
          |  if(fseek(main_file,0,SEEK_SET) == -1){
          |    rb_raise(cException,"Cloud not seek to the beginning of the file.");
          |  }
          |  \n#{classes.map do |klass|
            main_part =<<-SUBEND
            |\n#{if klass == StringElement
              <<-SUBSUBEND
              |  unsigned long string_element_size =
              |    (model_p->#{StringElement.struct_name}_size + 1) * page_size;
              |  if(write(model_p->lib_file,&string_element_size,
              SUBSUBEND
            else
              <<-SUBSUBEND
              |  if(write(model_p->lib_file,
              |    &(model_p->#{klass.struct_name}_count),
              SUBSUBEND
            end}
            |    sizeof(unsigned long)) == -1){
            |    rb_raise(cException,"Could not write #{klass.struct_name} count.");
            |  }
            |  if(write(model_p->lib_file,
            |    &(model_p->#{klass.struct_name}_offset),
            |    sizeof(unsigned long)) == -1){
            |    rb_raise(cException,"Could not write #{klass.struct_name} offset.");
            |  }\n
            SUBEND
            fields_part = klass.fields.map do |field,options|
              if options[:index]
                %w{length offset page}.map do |type|
                  str =<<-SUBEND
                  |  if(write(model_p->lib_file,
                  |    &(model_p->#{klass.struct_name}_#{field}_index_#{type}),
                  |    sizeof(unsigned long)) == -1){
                  |    rb_raise(cException,
                  |      "Could not write '#{klass.struct_name}' '#{field}' index #{type}.");
                  |  }
                  SUBEND
                end.join("\n")
              end
            end.join("\n")
            main_part + fields_part
          end.join("\n")}
          |  }
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
          classes.map do |klass|
             <<-SUBEND
             |  unsigned long #{klass.struct_name}_count;
             |  if(read(lib_file, &#{klass.struct_name}_count, sizeof(unsigned long)) == -1){
             |    rb_raise(cException,"Could not read #{klass.struct_name} count."); 
             |  }
             |  unsigned long #{klass.struct_name}_offset;
             |  if(read(lib_file, &#{klass.struct_name}_offset, sizeof(unsigned long)) == -1){
             |    rb_raise(cException,"Could not read #{klass.struct_name} offset."); 
             |  }
             #{klass.fields.map do |field,options|
               if options[:index]
                 %w{length offset page}.map do |type|
                   str =<<-SUBSUBEND
                   |  if(read(lib_file,&(model_p->#{klass.struct_name}_#{field}_index_#{type}),
                   |    sizeof(unsigned long)) == -1){
                   |    rb_raise(cException,
                   |      "Could not read '#{klass.struct_name}' '#{field}' index #{type}.");
                   |  }
                   SUBSUBEND
                 end.join("\n")
               end
             end.join("\n")}
             |  model_p->#{klass.struct_name}_size =
             |    (sizeof(#{klass.struct_name}) * #{klass.struct_name}_count / page_size)
             |      * page_size +
             |    (sizeof(#{klass.struct_name}) * #{klass.struct_name}_count % page_size ==
             |      0 ? 0 : page_size);
             |  model_p->#{klass.struct_name}_count = #{klass.struct_name}_count;
             |  model_p->#{klass.struct_name}_offset = #{klass.struct_name}_offset;
             |
             |  if(model_p->#{klass.struct_name}_size > 0){
             |    if((model_p->#{klass.struct_name}_table = mmap(NULL,
             |      model_p->#{klass.struct_name}_size, PROT_READ, MAP_SHARED,
             |      lib_file, model_p->#{klass.struct_name}_offset)) == MAP_FAILED){
             |      perror(NULL);
             |      rb_raise(cException,"Could not mmap class '#{klass}'.");
             |    }
             |  } else {
             |    model_p->#{klass.struct_name}_table = NULL;
             |  }
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

          classes.each do |klass|
            next if klass == JoinElement or klass == StringElement
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
          end
          str = <<-END
          |void _print_layout(VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  printf("=== Data layout START ===\\n");
          |  printf("File handler %d\\n",model_p->lib_file);
          |  \n#{classes.map do |klass|
               str =<<-SUBEND
          |  printf("-- #{klass} --\\n");
          |  printf("Size of #{klass.struct_name} %lu\\n",(unsigned long)sizeof(#{klass.struct_name}));
          |  \n#{klass.layout}
          |  printf("Size: %lu, offset: %lu, count %lu, last: %lu, pointer: %lx\\n",
          |    model_p->#{klass.struct_name}_size, model_p->#{klass.struct_name}_offset,
          |    model_p->#{klass.struct_name}_count, model_p->last_#{klass.struct_name},
          |    (unsigned long)model_p->#{klass.struct_name}_table);
               SUBEND
               str.margin
             end.join("\n")}
          |  printf("=== Data layout END ===\\n");
          |}
          END
          builder.c_singleton(str.margin)

          str =<<-END
          |void _print_system_error(){
          |  perror(NULL);
          |}
          END
          builder.c_singleton(str.margin)

          # This method is created to force rebuild of the C code, since
          # it is rebuild on the basis of methods' signatures change.
          builder.c_singleton("void __unused_method_#{rand(1000)}(){}")
        end
        @code_generated = true
      end
    end
  end
end
