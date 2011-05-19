require File.join(File.dirname(__FILE__),'constants')
require 'rod/abstract_database'

module Rod
  # This class implements (in C) the Database abstraction defined
  # in Rod::Database.
  #
  # Instance of the class should not be used *as* the database (i.e.
  # not in the macro-style function Rod::Model#database_class).
  # A user should strongly consider subclassing it, since refraining
  # from doing that, will not allow to use different databases for different
  # models simultaneously. This is due to the way RubyInline creates and
  # names (after the name of the class) the C code.
  class Database < AbstractDatabase
    # This flag indicates, if Database and Model works in development
    # mode, i.e. the dynamically loaded library has a unique, different id each time
    # the rod library is used.
    @@rod_development_mode = false

    # Writer of the +rod_development_mode+ flag.
    def self.development_mode=(value)
      @@rod_development_mode = value
    end

    # Reader of the +rod_development_mode+ flag.
    def self.development_mode
      @@rod_development_mode
    end

    protected

    ## Helper methods printing some generated code ##

    def model_struct_name(path)
      "model_" + path.gsub(/\W/,"_").squeeze("_")
    end

    # Initializes the C structures, which are based on the classes.
    def init_structs(classes)
      classes.map do |klass|
        <<-END
        |  // number of allocated pages
        |  model_p->#{klass.struct_name}_page_count = 0;
        |  // the number of allready stored structures
        |  model_p->#{klass.struct_name}_count = 0;
        |
        |  // initialize the tables with NULL to forbid unmapping
        |  model_p->#{klass.struct_name}_table = NULL;
        |
        |  // initialize the file descriptor to -1 to force its creation
        |  model_p->#{klass.struct_name}_lib_file = -1;
        END
      end.join("\n").margin
    end

    # Opens the file associated with the class. Creates it if it doesn't
    # exist.
    def open_class_file(klass)
      str =<<-END
      |// create the file unless it exists
      |if(model_p->#{klass.struct_name}_lib_file == -1){
      |  char * path = malloc(sizeof(char) * (strlen(model_p->path) +
      |    #{klass.struct_name.size} + #{".dat".size} + 1));
      |  strcpy(path,model_p->path);
      |  strcat(path,"#{klass.struct_name}.dat");
      |  model_p->#{klass.struct_name}_lib_file =
      |    open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
      |  if(model_p->lib_file == -1) {
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not open file %s for writing.",path);
      |  }
      |  free(path);
      |}
      END
      str.margin
    end

    # Mmaps the class to its page during database creation.
    def mmap_class(klass)
      str =<<-SUBEND
      |  //printf("mmaping #{klass}\\n");
      |  //unmap the segment(s) first
      |  if(model_p->#{klass.struct_name}_table != NULL){
      |    if(munmap(model_p->#{klass.struct_name}_table,
      |      page_size*(model_p->#{klass.struct_name}_page_count)) == -1){
      |      perror(NULL);
      |      VALUE cException = #{EXCEPTION_CLASS};
      |      rb_raise(cException,"Could not unmap segment for #{klass.struct_name}.");
      |    }
      |  }
      |  \n#{open_class_file(klass)}
      |
      |
      |  // exted the file
      |
      |  // increase the pages count by 1
      |  model_p->#{klass.struct_name}_page_count++;
      |
      |  // open the file for writing
      |  FILE * #{klass.struct_name}_file =
      |    fdopen(model_p->#{klass.struct_name}_lib_file,"w+");
      |  if(#{klass.struct_name}_file == NULL){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not open file for #{klass.struct_name}.");
      |  }
      |  // seek to the end
      |  if(fseek(#{klass.struct_name}_file,0,SEEK_END) == -1){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not seek to end file for #{klass.struct_name}.");
      |  }
      |  // write empty data at the end
      |  char* #{klass.struct_name}_empty_data = calloc(page_size,1);
      |  if(write(model_p->#{klass.struct_name}_lib_file,#{klass.struct_name}_empty_data,
      |    page_size) == -1){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not write to file for #{klass.struct_name}.");
      |  }
      |  // seek to the beginning
      |  if(fseek(#{klass.struct_name}_file,0,SEEK_SET) == -1){
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not seek to start file for #{klass.struct_name}.");
      |  }
      |  // mmap the extended file
      |  model_p->#{klass.struct_name}_table = mmap(NULL,
      |    model_p->#{klass.struct_name}_page_count * page_size,
      |    PROT_WRITE | PROT_READ, MAP_SHARED, model_p->#{klass.struct_name}_lib_file,0);
      |  if(model_p->#{klass.struct_name}_table == MAP_FAILED){
      |    perror(NULL);
      |    VALUE cException = #{EXCEPTION_CLASS};
      |    rb_raise(cException,"Could not mmap segment for #{klass.struct_name}.");
      |  }
      |
      |  // reset cache
      |  VALUE module_#{klass.struct_name} = rb_const_get(rb_cObject, rb_intern("Kernel"));
      |  \n#{klass.name.split("::")[0..-2].map do |mod_name|
        "  module_#{klass.struct_name} = rb_const_get(module_#{klass.struct_name}, " +
          "rb_intern(\"#{mod_name}\"));"
      end.join("\n")}
      SUBEND
      str.margin
    end

    # Returns true if the class is one of speciall classes
    # (JoinElement, PolymorphicJoinElement, StringElement).
    def special_class?(klass)
      self.class.special_classes.include?(klass)
    end

    #########################################################################
    # Implementations of abstract methods
    #########################################################################

    # Generates the code C responsible for management of the database.
    def generate_c_code(path, classes)
      if !@code_generated || @@rod_development_mode
        self.class.inline(:C) do |builder|
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

          #########################################
          # Model struct
          #########################################
          model_struct = model_struct_name(path);
          str = <<-END
            |typedef struct {
            |#{classes.map do |klass|
              substruct = <<-SUBEND
              |  #{klass.struct_name} * #{klass.struct_name}_table;
              |  unsigned long #{klass.struct_name}_page_count;
              |  unsigned long #{klass.struct_name}_count;
              |  int #{klass.struct_name}_lib_file;
              SUBEND
              indices =
                klass.fields.map do |field,options|
                  if options[:index]
                    str =<<-SUBEND
                    |  unsigned long #{klass.struct_name}_#{field}_index_length;
                    |  unsigned long #{klass.struct_name}_#{field}_index_offset;
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
            |} #{model_struct};
          END
          builder.prefix(str.margin)

          #########################################
          # Join indices
          #########################################
          str =<<-END
          |VALUE _join_element_indices(unsigned long element_offset, unsigned long count, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  _join_element * element_p;
          |  unsigned long element_index;
          |  VALUE result = rb_ary_new();
          |  for(element_index = 0; element_index < count; element_index++){
          |    element_p = model_p->_join_element_table + element_offset + element_index;
          |    rb_ary_push(result,UINT2NUM(element_p->offset));
          |  }
          |  return result;
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |VALUE _polymorphic_join_element_indices(unsigned long element_offset, unsigned long count, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  _polymorphic_join_element * element_p;
          |  unsigned long element_index;
          |  VALUE result = rb_ary_new();
          |  for(element_index = 0; element_index < count; element_index++){
          |    element_p = model_p->_polymorphic_join_element_table + element_offset + element_index;
          |    rb_ary_push(result,UINT2NUM(element_p->offset));
          |    rb_ary_push(result,UINT2NUM(element_p->class));
          |  }
          |  return result;
          |}
          END
          builder.c(str.margin)

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
          builder.c(str.margin)

          str =<<-END
          |void _set_polymorphic_join_element_offset(unsigned long element_offset,
          |  unsigned long element_index, unsigned long offset, unsigned long class_id,
          |  VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  _polymorphic_join_element * element_p;
          |  element_p = model_p->_polymorphic_join_element_table + element_offset + element_index;
          |  if(element_p->index != element_index){
          |      VALUE eClass = rb_const_get(rb_cObject, rb_intern("Exception"));
          |      rb_raise(eClass, "Polymorphic join element indices are inconsistent: %lu %lu!",
          |        element_index, element_p->index);
          |  }
          |  element_p->offset = offset;
          |  element_p->class = class_id;
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |unsigned long _allocate_join_elements(VALUE size, VALUE handler){
          |  _join_element * element;
          |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
          |  unsigned long index;
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  unsigned long result = model_p->_join_element_count;
          |  for(index = 0; index < size; index++){
          |    if(model_p->_join_element_count * sizeof(_join_element) >=
          |      page_size * model_p->_join_element_page_count){
          |      \n#{mmap_class(JoinElement)}
          |    }
          |    element = model_p->_join_element_table + model_p->_join_element_count;
          |    model_p->_join_element_count++;
          |    element->index = index;
          |    element->offset = 0;
          |  }
          |  return result;
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |unsigned long _allocate_polymorphic_join_elements(VALUE size, VALUE handler){
          |  _polymorphic_join_element * element;
          |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
          |  unsigned long index;
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  unsigned long result = model_p->_polymorphic_join_element_count;
          |  for(index = 0; index < size; index++){
          |    if(model_p->_polymorphic_join_element_count *
          |      sizeof(_polymorphic_join_element) >=
          |      page_size * model_p->_polymorphic_join_element_page_count){
          |      \n#{mmap_class(PolymorphicJoinElement)}
          |    }
          |    element = model_p->_polymorphic_join_element_table +
          |      model_p->_polymorphic_join_element_count;
          |    model_p->_polymorphic_join_element_count++;
          |    element->index = index;
          |    element->offset = 0;
          |    element->class = 0;
          |  }
          |  return result;
          |}
          END
          builder.c(str.margin)

          #########################################
          # Strings
          #########################################
          str =<<-END
          |VALUE _read_string(unsigned long length, unsigned long offset, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  char * str = model_p->#{StringElement.struct_name}_table + offset;
          |  return rb_str_new(str, length);
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |// The first argument is the string to be stored.
          |// The return value is a pair: length and offset.
          |VALUE _set_string(VALUE ruby_value, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
          |  unsigned long length = RSTRING_LEN(ruby_value);
          |  char * value = RSTRING_PTR(ruby_value);
          |  unsigned long string_offset, page_offset, current_page;
          |  char * dest;
          |  // table:
          |  // - address of the first page
          |  // page_count:
          |  // - during write - number of allocated pages
          |  // count:
          |  // - total number of bytes
          |  long length_left = length;
          |  // first free byte in current page
          |  string_offset = model_p->#{StringElement.struct_name}_count % page_size;
          |  page_offset = model_p->#{StringElement.struct_name}_count / page_size;
          |  current_page = page_offset;
          |  while(length_left > 0){
          |    if(length_left + string_offset >= page_size){
          |      \n#{mmap_class(StringElement)}
          |    }
          |    dest = model_p->#{StringElement.struct_name}_table +
          |      current_page * page_size + string_offset;
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
          |  model_p->#{StringElement.struct_name}_count += length;
          |
          |  VALUE result = rb_ary_new();
          |  rb_ary_push(result, UINT2NUM(length));
          |  rb_ary_push(result, UINT2NUM(string_offset + page_offset * page_size));
          |  return result;
          |}
          END
          builder.c(str.margin)

          #########################################
          # Field indices
          #########################################
          classes.each do |klass|
            next if special_class?(klass)
            klass.fields.each do |field,options|
              next unless options[:index]
              %w{length offset}.each do |type|
                str =<<-END
                |unsigned long _read_#{klass.struct_name}_#{field}_index_#{type}(VALUE handler){
                |  #{model_struct} * model_p;
                |  Data_Get_Struct(handler,#{model_struct},model_p);
                |  return model_p->#{klass.struct_name}_#{field}_index_#{type};
                |}
                END
                builder.c(str.margin)
              end
            end
          end

          #########################################
          # Object accessors
          #########################################
          classes.each do |klass|
            next if special_class?(klass)
            self.class.field_reader("#{klass.struct_name}_count",
                                    "unsigned long",builder,model_struct)
            self.class.field_writer("#{klass.struct_name}_count",
                                    "unsigned long",builder,model_struct)

            str = <<-END
            |VALUE _#{klass.struct_name}_get(VALUE handler, unsigned long index){
            |  #{model_struct} * model_p;
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  VALUE cClass = rb_define_class("#{klass.struct_class_name}",rb_cObject);
            |  return Data_Wrap_Struct(cClass,0,0,
            |    model_p->#{klass.struct_name}_table + index);
            |}
            END
            builder.c(str.margin)
          end

          #########################################
          # Storage
          #########################################
          classes.each do |klass|
            next if special_class?(klass)
            str =<<-END
            |// Store the object in the database.
            |void _store_#{klass.struct_name}(VALUE object, VALUE handler){
            |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
            |
            |  #{model_struct} * model_p;
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  if((model_p->#{klass.struct_name}_count+1) * sizeof(#{klass.struct_name}) >=
            |    model_p->#{klass.struct_name}_page_count * page_size){
            |     \n#{mmap_class(klass)}
            |  }
            |  #{klass.struct_name} * struct_p = model_p->#{klass.struct_name}_table +
            |    model_p->#{klass.struct_name}_count;
            |  //printf("struct assigned\\n");
            |  model_p->#{klass.struct_name}_count++;
            |  VALUE sClass = rb_funcall(object, rb_intern("class"),0);
            |  VALUE struct_object = Data_Wrap_Struct(sClass, 0, 0, struct_p);
            |
            |  //the number is incresed by 1, because 0 indicates that the
            |  //(referenced) object is nil
            |  struct_p->rod_id = model_p->#{klass.struct_name}_count;
            |  rb_iv_set(object, \"@rod_id\",UINT2NUM(struct_p->rod_id));
            |  rb_iv_set(object,"@struct",struct_object);
            |}
            END
            builder.c(str.margin)
          end

          #########################################
          # create
          #########################################
          str = <<-END
           |VALUE _create(char * dir_path){
           |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
           |  #{model_struct} * model_p;
           |  model_p = ALLOC(#{model_struct});
           |
           |  //join elements
           |  model_p->_elements_pages_count = 1;
           |
           |  #{init_structs(classes)}
           |
           |//prepare the file
           |  char * path = malloc(sizeof(char) * (strlen(dir_path) +
           |    #{DATABASE_FILE.size} + 1));
           |  strcpy(path,dir_path);
           |  strcat(path,"#{DATABASE_FILE}");
           |  char* empty = calloc(page_size,1);
           |  VALUE cException = #{EXCEPTION_CLASS};
           |  model_p->path = malloc(sizeof(char)*(strlen(dir_path)+1));
           |  strcpy(model_p->path,dir_path);
           |
           |  model_p->lib_file = open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
           |  if(model_p->lib_file == -1) {
           |    rb_raise(cException,"Could not open file %s for writing.",path);
           |  }
           |  free(path);
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
          builder.c(str.margin)

          #########################################
          # open
          #########################################
          str =<<-END
          |VALUE _open(char * dir_path){
          |  #{model_struct} * model_p;
          |  unsigned int page_size = sysconf(_SC_PAGE_SIZE);
          |  model_p = ALLOC(#{model_struct});
          |  char * path = malloc(sizeof(char) * (strlen(dir_path) +
          |    #{DATABASE_FILE.size} + 1));
          |  model_p->path = malloc(sizeof(char) * (strlen(dir_path) + 1));
          |  strcpy(model_p->path,dir_path);
          |  strcpy(path,dir_path);
          |  strcat(path,"#{DATABASE_FILE}");
          |  int lib_file = open(path, O_RDONLY);
          |  VALUE cException = #{EXCEPTION_CLASS};
          |  if(lib_file == -1) {
          |    rb_raise(cException,"Could not open data file %s for reading.",path);
          |  }
          |  free(path);
          |  unsigned long last_offset = page_size;
          |
          |  \n#{last_struct = nil
          classes.map do |klass|
             <<-SUBEND
             |  unsigned long #{klass.struct_name}_count;
             |  if(read(lib_file, &#{klass.struct_name}_count, sizeof(unsigned long)) == -1){
             |    rb_raise(cException,"Could not read #{klass.struct_name} count.");
             |  }
             |  unsigned long #{klass.struct_name}_page_count;
             |  if(read(lib_file, &#{klass.struct_name}_page_count, sizeof(unsigned long)) == -1){
             |    rb_raise(cException,"Could not read #{klass.struct_name} page count.");
             |  }
             #{klass.fields.map do |field,options|
               if options[:index]
                 %w{length offset}.map do |type|
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
             |  model_p->#{klass.struct_name}_count = #{klass.struct_name}_count;
             |  model_p->#{klass.struct_name}_page_count = #{klass.struct_name}_page_count;
             |  model_p->#{klass.struct_name}_lib_file = -1;
             |
             |  if(model_p->#{klass.struct_name}_page_count > 0){
             |    \n#{open_class_file(klass)}
             |    if((model_p->#{klass.struct_name}_table = mmap(NULL,
             |      model_p->#{klass.struct_name}_page_count * page_size, PROT_READ, MAP_SHARED,
             |      model_p->#{klass.struct_name}_lib_file, 0)) == MAP_FAILED){
             |      perror(NULL);
             |      rb_raise(cException,"Could not mmap class '#{klass}'.");
             |    }
             |  } else {
             |    model_p->#{klass.struct_name}_table = NULL;
             |  }
             |  last_offset += #{klass.struct_name}_page_count * page_size;
             SUBEND
          end.join("\n")}
          |  model_p->lib_file = lib_file;
          |  //create the wrapping object
          |  VALUE cClass = rb_define_class("#{model_struct_name(path).camelcase(true)}",
          |    rb_cObject);
          |  return Data_Wrap_Struct(cClass, 0, free, model_p);
          |}
          END
          builder.c(str.margin)

          #########################################
          # close
          #########################################
          str =<<-END
          |// if +classes+ are Qnil, the DB was open in readonly mode.
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
                SUBSUBEND
              end
            end.join("\n|\n")}
            SUBEND
          end.join("\n|\n")}
          |  }
          |  \n#{classes.map do |klass|
            <<-SUBEND
            |  if(model_p->#{klass.struct_name}_table != NULL){
            |    // XXX the size is invalid #38
            |    if(munmap(model_p->#{klass.struct_name}_table,page_size) == -1){
            |      rb_raise(cException,"Could not unmap #{klass.struct_name}.");
            |    }
            |  }
            SUBEND
          end.join("\n")}
          |  if(classes != Qnil){
          |    FILE * main_file = fdopen(model_p->lib_file,"w+");
          |    if(fseek(main_file,0,SEEK_SET) == -1){
          |      rb_raise(cException,"Cloud not seek to the beginning of the file.");
          |    }
          |  \n#{classes.map do |klass|
            main_part =<<-SUBEND
            |    close(model_p->#{klass.struct_name}_lib_file);
            |    if(write(model_p->lib_file,
            |      &(model_p->#{klass.struct_name}_count),
            |      sizeof(unsigned long)) == -1){
            |      rb_raise(cException,"Could not write #{klass.struct_name} count.");
            |    }
            |    if(write(model_p->lib_file,
            |      &(model_p->#{klass.struct_name}_page_count),
            |      sizeof(unsigned long)) == -1){
            |      rb_raise(cException,"Could not write #{klass.struct_name} page count.");
            |    }\n
            SUBEND
            fields_part = klass.fields.map do |field,options|
              if options[:index]
                %w{length offset}.map do |type|
                  str =<<-SUBEND
                  |    if(write(model_p->lib_file,
                  |      &(model_p->#{klass.struct_name}_#{field}_index_#{type}),
                  |      sizeof(unsigned long)) == -1){
                  |      rb_raise(cException,
                  |        "Could not write '#{klass.struct_name}' '#{field}' index #{type}.");
                  |    }
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
          builder.c(str.margin)


          #########################################
          # Utilities
          #########################################
          str = <<-END
          |void _print_layout(VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  printf("============= Data layout START =============\\n");
          |  printf("File handler %d\\n",model_p->lib_file);
          |  \n#{classes.map do |klass|
               str =<<-SUBEND
          |  printf("-- #{klass} --\\n");
          |  printf("Size of #{klass.struct_name} %lu\\n",(unsigned long)sizeof(#{klass.struct_name}));
          |  \n#{klass.layout}
          |  printf("Page count: %lu, count %lu, pointer: %lx\\n",
          |    model_p->#{klass.struct_name}_page_count,
          |    model_p->#{klass.struct_name}_count,
          |    (unsigned long)model_p->#{klass.struct_name}_table);
               SUBEND
               str.margin
             end.join("\n")}
          |  printf("============= Data layout END =============\\n");
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |void _print_system_error(){
          |  perror(NULL);
          |}
          END
          builder.c(str.margin)

          if @@rod_development_mode
            # This method is created to force rebuild of the C code, since
            # it is rebuild on the basis of methods' signatures change.
            builder.c_singleton("void __unused_method_#{rand(1000)}(){}")
          end
        end
        @code_generated = true
      end
    end

    # Reads the value of a specified field of the C-structure.
    def self.field_reader(name,result_type,builder,model_struct)
      str =<<-END
      |#{result_type} _#{name}(VALUE handler){
      |  #{model_struct} * model_p;
      |  Data_Get_Struct(handler,#{model_struct},model_p);
      |  return model_p->#{name};
      |}
      END
      builder.c(str.margin)
    end

    # Writes the value of a specified field of the C-structure.
    def self.field_writer(name,arg_type,builder,model_struct)
      str =<<-END
      |void _#{name}_equals(VALUE handler,#{arg_type} value){
      |  #{model_struct} * model_p;
      |  Data_Get_Struct(handler,#{model_struct},model_p);
      |  model_p->#{name} = value;
      |}
      END
      builder.c(str.margin)
    end
  end
end
