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
      index = 0 
      classes.map do |klass|
        # leave one segment for stats - index _is_ incremented
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

    def self.size_of_page(klass)
      if klass != ::Rod::StringElement
        "per_page * sizeof(#{klass.struct_name})"
      else
        "page_size"
      end
    end

    def self.extend_data_file(klass)
      str = <<-END
      |  model_p->_last_offset++;
      |  model_p->#{klass.struct_name}_offset = model_p->_last_offset;
      |  FILE * file = fdopen(model_p->lib_file,"w+");
      |  if(file == NULL){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not open file for #{klass.struct_name}.");
      |  } 
      |  if(fseek(file,0,SEEK_END) == -1){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not seek file for #{klass.struct_name}.");
      |  }
      |  char* empty = calloc(page_size,1);
      |  if(write(model_p->lib_file,empty,page_size) == -1){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not extend file for #{klass.struct_name}.");
      |  }
      END
      str.margin
    end

    # Mmaps the class to its page during database creation.
    # TODO merge with extend data file
    def self.mmap_class(klass)
      str =<<-SUBEND
      |  model_p->#{klass.struct_name}_table = mmap(NULL, page_size,
      |    PROT_WRITE | PROT_READ, MAP_SHARED, model_p->lib_file, 
      |    model_p->#{klass.struct_name}_offset * page_size);
      |  if(model_p->#{klass.struct_name}_table == MAP_FAILED){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could mmap segment for #{klass.struct_name}.");
      |  }
      |  model_p->last_#{klass.struct_name} = 0;
      |  VALUE module_#{klass.struct_name} = rb_const_get(rb_cObject, rb_intern("Kernel"));
      |  \n#{klass.name.split("::")[0..-2].map do |mod_name|
        "  module_#{klass.struct_name} = rb_const_get(module_#{klass.struct_name}, " +
          "rb_intern(\"#{mod_name}\"));"
      end.join("\n")}
      |  VALUE class_#{klass.struct_name} = rb_const_get(module_#{klass.struct_name},
      |    rb_intern("#{klass.name.split("::")[-1]}")); 
      |  VALUE offsets_#{klass.struct_name} = rb_funcall(class_#{klass.struct_name},
      |    rb_intern("page_offsets"),0);
      |  rb_ary_push(offsets_#{klass.struct_name},
      |    INT2NUM(model_p->#{klass.struct_name}_offset));
      SUBEND
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

    ####

    # Computes rearrangement of pages for the +classes+ array
    # in which +current_klass+'s instances are placed continuously on subsequent pages
    # keeping the order of remaining classes intact
    # returns an array containing 3 subarrays:
    #   * current class's offsets a, such that
    #      a[i] represents a number of page from the old order to be placed at i
    #   * other classes' offsets b
    #   * new other classes' offsets c, such that b[i] in old order should be placed at c[i]
    def self.arrange_pages(current_klass, classes)
      klass_offsets = current_klass.page_offsets.dup
      if klass_offsets.empty?
        return [[],[],[]]
      end

      offset_map = {}	#contains a class for each page offset
      classes.each do |klass| 
        klass.page_offsets.each do |offset| 
          if offset_map.has_key?(offset)
            raise "Offset assignment conflict: #{offset} - #{klass} & #{offset_map[offset]}"
          end
          offset_map[offset] = klass
        end
      end
      # changes are going to have place in this range
      range = (klass_offsets.first..klass_offsets.last)

      offsets = []
      other_offsets = []  #offsets of pages used for other classes than current_klass
      range.each do |offset|
        offsets << [offset, offset_map[offset]]
        # offset inside the range, but different class on this page
        if offset_map[offset] != current_klass 
          other_offsets << offset
        end
      end

      #stable sort
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
            |  // the pointer to join elements table
            |  _join_element ** _elements_tables_table;
            |
            |  // the handler to the file containing the data
            |  int lib_file;
            |
            |  // the offset of the last page
            |  unsigned long _last_offset;
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
           |  //TODO destroy properly
           |  model_p->_elements_tables_table = malloc(sizeof(_join_element *)*2); 
           |  
           |  #{init_structs(classes)}
           |  model_p->#{StringElement.struct_name}_size = 0;
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
           |  model_p->_last_offset = model_p->#{classes.last.struct_name}_offset;
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
          |  unsigned long offset, page;
          |  char * dest;
          |  // table:
          |  // - during write - current page
          |  // - durign read - first page
          |  // last:
          |  // - during write - first free byte in current page
          |  // offset:
          |  // - during write - offset of current page
          |  // - during read - offset in file
          |  // size:
          |  // - during write - number of pages - 1
          |  // count:
          |  // - total number of bytes
          |  if(length + model_p->last_#{StringElement.struct_name} > page_size){
          |    long length_left = length;
          |    page = model_p->#{StringElement.struct_name}_size + 1;
          |    offset = 0;
          | 
          |    while(length_left > 0){
          |      \n#{extend_data_file(StringElement)}
          |      \n#{mmap_class(StringElement)}
          |      dest = model_p->#{StringElement.struct_name}_table;
          |      if(length_left > page_size){
          |        memcpy(dest,value,page_size);
          |      } else {
          |        memcpy(dest,value,length_left);
          |      }
          |      value += page_size; 
          |
          |      model_p->#{StringElement.struct_name}_size++;
          |      length_left -= page_size;
          |    }
          |  } else {
          |    offset = model_p->last_#{StringElement.struct_name};
          |    dest = model_p->#{StringElement.struct_name}_table + offset;
          |    page = model_p->#{StringElement.struct_name}_size;
          |    memcpy(dest, value,length);
          |  }
          |
          |  model_p->last_#{StringElement.struct_name} += (length + 1) % page_size;
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
            |  if(model_p->last_#{klass.struct_name} >= model_p->#{klass.struct_name}_size){
            |     //VALUE cException = #{EXCEPTION_CLASS};
            |     //if(munmap(model_p->#{klass.struct_name}_table, page_size) == -1){
            |     //  rb_raise(cException,"Could not unmap #{klass.struct_name} (during store)."); 
            |     //}
            |     //printf("extending file\\n");
            |     \n#{extend_data_file(klass)}
            |     //printf("mmaping new file fragment\\n");
            |     \n#{mmap_class(klass)}
            |  } 
            |  VALUE result = INT2NUM(model_p->#{klass.struct_name}_offset);
            |  #{klass.struct_name} * struct_p = model_p->#{klass.struct_name}_table +
            |    model_p->last_#{klass.struct_name}++;
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
              |      if(model_p->last__join_element >= per_page){
              |        model_p->last__join_element = 0;
              |        model_p->_elements_pages_count++;
              |        \n#{extend_data_file(JoinElement)} 
              |        \n#{mmap_class(JoinElement)}
              |        model_p->_elements_tables_table[model_p->_elements_pages_count-1] = 
              |          model_p->_join_element_table;
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
          |  VALUE klass, klass_offsets;
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
            |      //printf("Warn: failed to unmap #{klass.struct_name}\\n");
            |      rb_raise(cException,"Could not unmap #{klass.struct_name}."); 
            |    }
            |  }
            SUBEND
          end.join("\n")}
          |  // unmap all mmaped regions TODO !!!
          |  /*klass_offsets = rb_funcall(klass,rb_intern("offsets"),0);
          |  offsets_count = NUM2ULONG(rb_funcall(klass_offsets,rb_intern("size"),0));
          |  for(offsets_index; offsets_index < offsets_count; offsets_index++){
          |    NUM2ULONG(rb_ary_entry(klass_offsets,offsets_index));
          |    //TODO
          |  }*/
          |
          |  if(classes != Qnil){
          |    VALUE pages, other_offsets, new_offsets;
          |    FILE * file;
          |    unsigned long size, offset, per_page, j;
          |    char * pages_copy, * one_page;
          |    //we have to reorganize pages
          |    file = fdopen(model_p->lib_file,"w+");
          |    if(file == NULL){
          |      rb_raise(cException,"Could not open file while closing DB.");
          |    } 
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
          |      if(fseek(file, page_size * offset, SEEK_SET) == -1){
          |        rb_raise(cException,"Could not seek while copying pages");
          |      }
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
          |        //TODO: no need to do it in loop
          |        model_p->#{klass.struct_name}_offset = offset * page_size; 
          |      }
          |      if(fseek(file, page_size * offset, SEEK_SET) == -1){
          |        rb_raise(cException,"Could not seek while rearranging pages (1)");
          |      }
          |      if(read(model_p->lib_file, one_page, page_size) == -1){ //MS: why we read page_size while writing size_of_page(klass) below?
          |        rb_raise(cException,"Could not read file during re-arrangement (class data)."); 
          |      }
          |      if(fseek(file, model_p->#{klass.struct_name}_offset + 
          |         #{size_of_page(klass)} * j,SEEK_SET) == -1){
          |        rb_raise(cException,"Could not seek while copying pages (2)");
          |      }
          |      if(write(model_p->lib_file, one_page, #{size_of_page(klass)}) == -1){
          |        rb_raise(cException,"Could not write to file during re-arrangement (class data)."); 
          |      }
          |    }
          |    free(one_page);
          | 
          |    // write back data from the memory    
          |    size = NUM2ULONG(rb_funcall(new_offsets,rb_intern("size"),0));
          |    for(j=0; j < size; j++){ 
          |      offset = NUM2ULONG(rb_ary_entry(new_offsets,j));
          |      if(fseek(file, offset * page_size, SEEK_SET) == -1){
          |        rb_raise(cException,"Could not seek while writing data back from memory.");
          |      } 
          |      if(write(model_p->lib_file, pages_copy + j * page_size, page_size) == -1){
          |        rb_raise(cException,"Could not write to file during re-arrangement (copy back)."); 
          |      }
          |    }
          |     
          |    free(pages_copy);
          SUBEND
          end.join("\n")}
          |  if(fseek(file,0,SEEK_SET) == -1){
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
             |    model_p->#{klass.struct_name}_table = mmap(NULL, 
             |      model_p->#{klass.struct_name}_size, PROT_READ, MAP_SHARED, 
             |      lib_file, model_p->#{klass.struct_name}_offset);
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
          |  printf("Offset of the last page %lu\\n",model_p->_last_offset);
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
          |  printf("Number of pages of join elements (only during create): %lu, \\n"
          |    "  pointer to join elements %lx\\n",
          |    model_p->_elements_pages_count,(unsigned long)model_p->_elements_tables_table);
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
