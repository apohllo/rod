require File.join(File.dirname(__FILE__),'constants')

module Rod
  class Service
    # Closes the database.
    def self.close(handler, classes)
      _close(handler, classes) 
    end

    def self.model_struct_name(path)
      "model_" + path.gsub(/\W/,"_").squeeze("_")
    end

    def self.init_structs(classes)
      index = 0 
      classes.map do |klass|
        # leav one segment for stats - index _is_ incremented
        # before evaluation
        index += 1
        <<-END
        |  // first page offset
        |  model_p->#{klass.struct_name}_offset = #{index};
        | 
        |  // maximal number of structures on one page
        |  model_p->#{klass.struct_name}_size = page_size / sizeof(#{klass.struct_name});
        |  
        |  // the number of allready stored structures 
        |  model_p->#{klass.struct_name}_count = 0;
        END
      end.join("\n").margin
    end

    def self.mmap_class(klass)
      str =<<-SUBEND
      |  model_p->#{klass.struct_name}_table = mmap(NULL, page_size,
      |    PROT_WRITE | PROT_READ, MAP_SHARED, model_p->lib_file, 
      |    model_p->#{klass.struct_name}_offset * page_size);
      |  model_p->last_#{klass.struct_name} = 0;
      SUBEND
      str.margin
    end

    def self.extend_data_file(klass)
      str = <<-END
      |   model_p->last_offset++;
      |   model_p->#{klass.struct_name}_offset = model_p->last_offset;
      |   FILE * file = fdopen(model_p->lib_file,"w+");
      |   fseek(file,0,SEEK_END);
      |   if(write(model_p->lib_file,empty,page_size) == -1){
      |     rb_raise(cException,"Could not extend file for #{klass.struct_name}.");
      |   }
      END
      str.margin
    end

    def self.calculate_element_p
      str =<<-END
      |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
      |  unsigned long per_page = page_size / sizeof(_join_element);
      |  unsigned long page_index = (element_offset + element_index)/per_page;
      |  element_p = model_p->_elements_tables_table[page_index] +
      |    element_offset + element_index - page_index * per_page;
      END
      str.margin
    end

    def self.arrange_pages(current_klass, classes)
      klass_offsets = current_klass.page_offsets.dup
      if klass_offsets.empty?
        return [[],[],[]]
      end
      offset_map = {}
      classes.each do |klass| 
        klass.page_offsets.each do |offset| 
          if offset_map.has_key?(offset)
            raise "Offset assignment conflict: #{offset} - #{klass} & #{offset_map[offset]}"
          end
          offset_map[offset] = klass
        end
      end
      range = (klass_offsets.first..klass_offsets.last)

      offsets = []
      other_offsets = []
      range.each do |offset|
        offsets << [offset, offset_map[offset]]
        if offset_map[offset] != current_klass 
          other_offsets << offset
        end
      end
      offsets.sort! do |e1, e2|
        offset1, klass1 = *e1
        offset2, klass2 = *e2
        if klass1 == klass2
          offset1 <=> offset2
        else
          classes.index(klass1) <=> classes.index(klass2)
        end
      end

      original_klass_offsets = {}
      classes.each{|c| original_klass_offsets[c] = c.page_offsets.dup}
      new_offsets = []
      offsets.each_with_index do |offset_and_klass, new_offset|
        offset, klass = *offset_and_klass
        if klass != current_klass
          new_offsets[other_offsets.index(offset)] = 
            offsets.first[0] + new_offset
        end
        offset_index = original_klass_offsets[klass].index(offset)
        klass.page_offsets[offset_index] = offsets.first[0] + new_offset
      end

      [klass_offsets, other_offsets, new_offsets]
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
                SUBEND
                substruct.margin
              end.join("\n")}
            |  unsigned long _elements_pages_count;
            |  _join_element ** _elements_tables_table;
            |  int lib_file;
            |  unsigned long last_offset;
            |} #{model_struct};
          END
          builder.prefix(str.margin)

          str = <<-END
           |VALUE _create(char * path){
           |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
           |  #{model_struct} * model_p;
           |  model_p = ALLOC(#{model_struct});
           |  model_p->_elements_pages_count = 1;
           |  //TODO destroy properly
           |  model_p->_elements_tables_table = malloc(sizeof(_join_element *)*2); 
           |
           |  #{init_structs(classes)}
           |
           |//prepare the file
           |  char* empty = calloc(page_size,1);
           |  int index;
           |  VALUE cException = #{EXCEPTION_CLASS};
           |  model_p->lib_file = open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
           |  if(model_p->lib_file == -1) {
           |    rb_raise(cException,"Could not open file %s for writing.",path); 
           |  }
           |  
           |  if(write(model_p->lib_file,empty,page_size) == -1){
           |    rb_raise(cException,"Could not fill stats with empty data.");
           |  }
           |  
           |  // fill data space with empty data
           |  unsigned long file_size = page_size * #{classes.size + 1};
           | 
           |  for(index = 1; index < file_size / page_size;index++){
           |    if(write(model_p->lib_file, empty, page_size) == -1){
           |      rb_raise(cException,"Could not fill data space with empty data.");
           |    }
           |  }
           |  
           |  //mmap the structures
           |  \n#{classes.map{|klass| mmap_class(klass)}.join("\n|\n")}
           |  model_p->last_offset = model_p->#{classes.last.struct_name}_offset;
           |  model_p->_elements_tables_table[0] = model_p->_join_element_table;
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
          |    if(model_p->_elements_tables_table == NULL){
          |      element_p = model_p->_join_element_table + element_offset + element_index;
          |    } else {
          |      #{calculate_element_p}
          |    }
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
          |  #{calculate_element_p}
          |  if(element_p->index != element_index){
          |      VALUE eClass = rb_const_get(rb_cObject, rb_intern("Exception"));
          |      rb_raise(eClass, "Join element indices are inconsistent: %lu %lu!",
          |        element_index, element_p->index);
          |  } 
          |  element_p->offset = offset;
          |}
          END
          builder.c_singleton(str.margin)

          classes.each do |klass|
            next if klass == ::Rod::JoinElement
            str =<<-END
            |// Store the object in the database.
            |// The value returned is the index of the page
            |VALUE _store_#{klass.struct_name}(VALUE object, VALUE handler){
            |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
            |  char* empty = calloc(page_size,1);
            | 
            |  #{model_struct} * model_p;
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  if(model_p->last_#{klass.struct_name} >= model_p->#{klass.struct_name}_size){
            |     VALUE cException = #{EXCEPTION_CLASS};
            |     //if(munmap(model_p->#{klass.struct_name}_table, page_size) == -1){
            |     //  rb_raise(cException,"Could not unmap #{klass.struct_name} (during store)."); 
            |     //}
            |     \n#{extend_data_file(klass)}
            |     \n#{mmap_class(klass)}
            |  } 
            |  VALUE result = INT2NUM(model_p->#{klass.struct_name}_offset);
            |  #{klass.struct_name} * struct_p = model_p->#{klass.struct_name}_table +
            |    model_p->last_#{klass.struct_name}++;
            |  model_p->#{klass.struct_name}_count++;
            |
            |  \n#{klass.fields.map do |field, type|
               raise "TODO implement" if type == :string
               if field == "rod_id"
                 # the number is incresed by 1, because 0 indicates that the 
                 # (refered) object is nil
                 "|  struct_p->rod_id = model_p->#{klass.struct_name}_count;\n"+
                 "|  rb_iv_set(object, \"@rod_id\",INT2NUM(struct_p->rod_id));"
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
            |  #{unless klass.plural_associations.empty?
              "unsigned long per_page = page_size / sizeof(_join_element);"
            end}
            |  \n#{klass.plural_associations.map do |name, options|
              <<-SUBEND
              |  VALUE referenced_#{name} = rb_funcall(object, rb_intern("#{name}"),0);
              |  struct_p->#{name}_offset = model_p->_join_element_count;
              |  if(referenced_#{name} == Qnil){
              |    struct_p->#{name}_count = 0;
              |  } else {
              |    VALUE aClass = rb_const_get(rb_cObject, rb_intern("Array"));
              |    VALUE cException = #{EXCEPTION_CLASS};
              |    if(!rb_obj_is_kind_of(referenced_#{name},aClass)){
              |      //rb_raise(eClass, "#{name} doesn't return an instance of Array");
              |    }
              |    _join_element * element;
              |    unsigned long size = NUM2ULONG(rb_funcall(referenced_#{name},
              |      rb_intern("size"),0));
              |    struct_p->#{name}_count = size;
              |    unsigned long index;
              |    for(index = 0; index < size; index++){
              |      if(model_p->last__join_element >= per_page){
              |        model_p->last__join_element = 0;
              |        model_p->_elements_pages_count++;
              |        \n#{extend_data_file(JoinElement)} 
              |        \n#{mmap_class(JoinElement)}
              |        model_p->_elements_tables_table[model_p->_elements_pages_count-1] = 
              |          model_p->_join_element_table;
              |        
              |        VALUE rod_module = rb_const_get(rb_cObject, rb_intern("Rod"));
              |        VALUE element_class = rb_const_get(rod_module, rb_intern("JoinElement"));
              |        VALUE element_page_offsets = rb_funcall(element_class,
              |          rb_intern("page_offsets"),0);
              |        rb_ary_push(element_page_offsets,INT2NUM(model_p->last_offset));
              |        
              |        // check if the tables table has to be extended
              |        unsigned long pages_count = model_p->_elements_pages_count;
              |        int power_of_2 = 1;
              |        while(pages_count > 0){
              |          if(pages_count % 2 != 0 && pages_count != 1){
              |            power_of_2 = 0;
              |          }
              |          pages_count /= 2;
              |        }
              |        if(power_of_2 == 1){
              |          // we have to double the size of elements tables table
              |          _join_element ** old_table = model_p->_elements_tables_table;
              |          model_p->_elements_tables_table = malloc(sizeof(_join_element)* 2 * 
              |            model_p->_elements_pages_count);
              |          int i;
              |          for(i=0;i<model_p->_elements_pages_count;i++){
              |            model_p->_elements_tables_table[i] = old_table[i];
              |          } 
              |          free(old_table);
              |        }
              |      }
              |      element = model_p->_join_element_table + model_p->last__join_element++;
              |      model_p->_join_element_count++;
              |      element->offset = NUM2ULONG(rb_funcall(rb_ary_entry(referenced_#{name},index),
              |        rb_intern("rod_id"),0));
              |      element->index = index;
              |    } 
              |  }
              SUBEND
            end.join("\n")}
            |  VALUE sClass = rb_funcall(object, rb_intern("class"),0);
            |  rb_iv_set(object,"@struct",Data_Wrap_Struct(sClass, 0, 0, struct_p));
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
          |  VALUE klass, klass_offsets;
          |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
          |  /*unsigned long classes_index, classes_count, offsets_index, offsets_count;
          |  classes_count = NUM2ULONG(rb_funcall(classes,rb_intern("size"),0));
          |  for(classes_index = 0; classes_index < classes_count; classes_index++){
          |     klass = rb_ary_entry(classes, classes_index);
          |     klass_offsets = rb_funcall(klass,rb_intern("offsets"),0);
          |     offsets_count = NUM2ULONG(rb_funcall(klass_offsets,rb_intern("size"),0));
          |     for(offsets_index; offsets_index < offsets_count; offsets_index++){
          |       NUM2ULONG(rb_ary_entry(klass_offsets,offsets_index));
          |       //TODO
          |     }
          |  }*/
          |  \n#{classes.map do |klass|
               <<-SUBEND
               |  if(munmap(model_p->#{klass.struct_name}_table,
               |    model_p->#{klass.struct_name}_size) == -1){
               |    rb_raise(cException,"Could not unmap #{klass.struct_name}."); 
               |  }
               SUBEND
          end.join("\n")}
          |  if(classes != Qnil){
          |    VALUE pages, other_offsets, new_offsets;
          |    FILE * file;
          |    unsigned long size, offset, per_page, j;
          |    char * pages_copy, * one_page;
          |    //we have to reorganize pages
          |    file = fdopen(model_p->lib_file,"w+");
          |    \n#{classes.map.with_index do |klass, i|
          <<-SUBEND
          |    klass = rb_ary_entry(classes,#{i});
          |    pages = rb_funcall(self,
          |      rb_intern("arrange_pages"),2,klass,classes);
          |    klass_offsets = rb_ary_entry(pages,0);
          |    other_offsets = rb_ary_entry(pages,1);
          |    new_offsets = rb_ary_entry(pages,2);
          |    
          |    // copy pages of other classes to the memory
          |    size = NUM2ULONG(rb_funcall(other_offsets,rb_intern("size"),0));
          |    pages_copy = malloc(page_size * size);
          |    for(j=0; j < size;j++){
          |      offset = NUM2ULONG(rb_ary_entry(other_offsets,j));
          |      fseek(file, page_size * offset, SEEK_SET);
          |      if(read(model_p->lib_file, pages_copy + page_size * j, page_size) == -1){
          |        rb_raise(cException,"Could not read file during re-arrangement (copying)."); 
          |      }
          |    }
          |    
          |    // rearrange data of current class
          |    one_page = malloc(page_size);
          |    per_page = page_size / sizeof(#{klass.struct_name});
          |    size = NUM2ULONG(rb_funcall(klass_offsets,rb_intern("size"),0));
          |    for(j=0; j < size; j++){
          |      offset = NUM2ULONG(rb_ary_entry(klass_offsets,j));
          |      if(j == 0){
          |        model_p->#{klass.struct_name}_offset = offset * page_size;
          |      }
          |      fseek(file, page_size * offset, SEEK_SET);
          |      if(read(model_p->lib_file, one_page, page_size) == -1){
          |        rb_raise(cException,"Could not read file during re-arrangement (class data)."); 
          |      }
          |      fseek(file, model_p->#{klass.struct_name}_offset + 
          |        per_page * sizeof(#{klass.struct_name}) * j,SEEK_SET);
          |      if(write(model_p->lib_file, one_page, 
          |        per_page * sizeof(#{klass.struct_name})) == -1){
          |        rb_raise(cException,"Could not write to file during re-arrangement (class data)."); 
          |      }
          |    }
          |    free(one_page);
          | 
          |    // write back data from the memory    
          |    size = NUM2ULONG(rb_funcall(new_offsets,rb_intern("size"),0));
          |    for(j=0; j < size; j++){ 
          |      offset = NUM2ULONG(rb_ary_entry(new_offsets,j));
          |      fseek(file, offset * page_size, SEEK_SET);
          |      if(write(model_p->lib_file, pages_copy + j * page_size, page_size) == -1){
          |        rb_raise(cException,"Could not write to file during re-arrangement (copy back)."); 
          |      }
          |    }
          |     
          |    free(pages_copy);
          SUBEND
          end.join("\n")}
          |  fseek(file,0,SEEK_SET);
          |  \n#{classes.map do |klass|
          <<-SUBEND
          |  if(write(model_p->lib_file,
          |    &(model_p->#{klass.struct_name}_count),
          |    sizeof(unsigned long)) == -1){
          |    rb_raise(cException,"Could not write #{klass.struct_name} count.");
          |  }
          |  if(write(model_p->lib_file,
          |    &(model_p->#{klass.struct_name}_offset),
          |    sizeof(unsigned long)) == -1){
          |    rb_raise(cException,"Could not write #{klass.struct_name} count.");
          |  }\n
          SUBEND
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
          |  model_p->_elements_tables_table = NULL;
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
             |    rb_raise(cException,"Could not read #{klass.struct_name} count."); 
             |  }
             |  model_p->#{klass.struct_name}_size =  
             |    (sizeof(#{klass.struct_name}) * #{klass.struct_name}_count / page_size) 
             |      * page_size + 
             |    (sizeof(#{klass.struct_name}) * #{klass.struct_name}_count % page_size == 
             |      0 ? 0 : page_size);
             |  if(model_p->#{klass.struct_name}_size == 0){
             |    // at least one page is reserved for every model
             |    model_p->#{klass.struct_name}_size = page_size;
             |  }
             |  model_p->#{klass.struct_name}_count = #{klass.struct_name}_count;
             |  model_p->#{klass.struct_name}_offset = #{klass.struct_name}_offset;
             |
             |//printf("size: #{klass.struct_name} %lu\\n",
             |//  model_p->#{klass.struct_name}_size/page_size);
             |//printf("off: #{klass.struct_name} %lu\\n",
             |//  model_p->#{klass.struct_name}_offset/page_size);
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

          classes.each do |klass|
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
