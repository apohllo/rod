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
      |  // create the file unless it exists
      |  if(model_p->#{klass.struct_name}_lib_file == -1){
      |    char * path = malloc(sizeof(char) * (strlen(model_p->path) +
      |      #{klass.path_for_data("").size} + 1));
      |    strcpy(path,model_p->path);
      |    strcat(path,"#{klass.path_for_data("")}");
      |    model_p->#{klass.struct_name}_lib_file =
      |      open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
      |    if(model_p->#{klass.struct_name}_lib_file == -1) {
      |      rb_raise(rodException(),"Could not open file for class #{klass} on path %s writing.",path);
      |    }
      |    free(path);
      |  }
      END
      str.margin
    end

    # Updates the pointer to table of structs for a given +klass+ when
    # the klass is (re)mmaped.
    def update_pointer(klass)
      str =<<-END
      |  {
      |    VALUE cClass = rb_cObject;
      |    #{klass.to_s.split("::").map do |name|
          "cClass = rb_const_get(cClass, rb_intern(\"#{name}\"));"
        end.join("\n|    ")}
      |    rb_funcall(cClass, rb_intern("rod_pointer="),1,
      |      ULONG2NUM((unsigned long)model_p->#{klass.struct_name}_table));
      |  }
      END
      str.margin
    end

    # Mmaps the class to its page during database creation.
    def mmap_class(klass)
      str =<<-END
      |  //printf("mmaping #{klass}\\n");
      |  //unmap the segment(s) first
      |  if(model_p->#{klass.struct_name}_table != NULL){
      |    if(munmap(model_p->#{klass.struct_name}_table,
      |      page_size()*(model_p->#{klass.struct_name}_page_count)) == -1){
      |      perror(NULL);
      |      rb_raise(rodException(),"Could not unmap segment for #{klass.struct_name}.");
      |    }
      |  }
      |  \n#{open_class_file(klass)}
      |
      |
      |  // exted the file
      |
      |  // increase the pages count by 1
      |  model_p->#{klass.struct_name}_page_count += ALLOCATED_PAGES;
      |  {
      |    // open the file for writing
      |    char* #{klass.struct_name}_empty_data;
      |    FILE * #{klass.struct_name}_file =
      |      fdopen(model_p->#{klass.struct_name}_lib_file,"w+");
      |    if(#{klass.struct_name}_file == NULL){
      |      rb_raise(rodException(),"Could not open file for #{klass.struct_name}.");
      |    }
      |    // seek to the end
      |    if(fseek(#{klass.struct_name}_file,0,SEEK_END) == -1){
      |      rb_raise(rodException(),"Could not seek to end file for #{klass.struct_name}.");
      |    }
      |    // write empty data at the end
      |    #{klass.struct_name}_empty_data = calloc(page_size() * ALLOCATED_PAGES,1);
      |    if(write(model_p->#{klass.struct_name}_lib_file,#{klass.struct_name}_empty_data,
      |      page_size() * ALLOCATED_PAGES) == -1){
      |      rb_raise(rodException(),"Could not write to file for #{klass.struct_name}.");
      |    }
      |    // seek to the beginning
      |    if(fseek(#{klass.struct_name}_file,0,SEEK_SET) == -1){
      |      rb_raise(rodException(),"Could not seek to start file for #{klass.struct_name}.");
      |    }
      |    // mmap the extended file
      |    model_p->#{klass.struct_name}_table = mmap(NULL,
      |      model_p->#{klass.struct_name}_page_count * page_size(),
      |      PROT_WRITE | PROT_READ, MAP_SHARED, model_p->#{klass.struct_name}_lib_file,0);
      |    if(model_p->#{klass.struct_name}_table == MAP_FAILED){
      |      perror(NULL);
      |      rb_raise(rodException(),"Could not mmap segment for #{klass.struct_name}.");
      |    }
      |  }
      |#{update_pointer(klass) unless special_class?(klass)}
      END
      str.margin
    end

    # Returns true if the class is one of speciall classes
    # (JoinElement, PolymorphicJoinElement, StringElement).
    def special_class?(klass)
      self.special_classes.include?(klass)
    end

    #########################################################################
    # Implementations of abstract methods
    #########################################################################

    # Ruby inline generated shared library name.
    def inline_library
      unless defined?(@inline_library)
        self.class.inline(:C) do |builder|
          builder.c_singleton("void __unused_method_#{rand(1000000)}(){}")

          self.instance_variable_set("@inline_library",builder.so_name)
        end
      end
      @inline_library
    end


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

          builder.prefix("const ALLOCATED_PAGES = 25;")

          str =<<-END
          |unsigned int page_size(){
          |  return sysconf(_SC_PAGE_SIZE);
          |}
          END
          builder.prefix(str.margin)

          builder.prefix(self.class.rod_exception)


          #########################################
          # Model struct
          #########################################
          model_struct = model_struct_name(path);
          str = <<-END
            |typedef struct {\n
            #{classes.map do |klass|
              <<-SUBEND
              |  #{klass.struct_name} * #{klass.struct_name}_table;
              |  unsigned long #{klass.struct_name}_page_count;
              |  unsigned long #{klass.struct_name}_count;
              |  int #{klass.struct_name}_lib_file;
              SUBEND
            end.join("\n|\n")}
            |  // the path to the DB
            |  char * path;
            |
            |} #{model_struct};
          END
          builder.prefix(str.margin)

          #########################################
          # Join indices
          #########################################
          str =<<-END
          |VALUE _join_element_index(unsigned long element_offset, unsigned long element_index, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  return ULONG2NUM((model_p->_join_element_table + element_offset + element_index)->offset);
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |VALUE _polymorphic_join_element_index(unsigned long element_offset,
          |  unsigned long element_index, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  return ULONG2NUM((model_p->_polymorphic_join_element_table +
          |    element_offset + element_index)->offset);
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |VALUE _polymorphic_join_element_class(unsigned long element_offset,
          |  unsigned long element_index, VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  return ULONG2NUM((model_p->_polymorphic_join_element_table +
          |    element_offset + element_index)->class);
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |void _set_join_element_offset(unsigned long element_offset,
          |  unsigned long element_index, unsigned long offset,
          |  VALUE handler){
          |  #{model_struct} * model_p;
          |  _join_element * element_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  element_p = model_p->_join_element_table + element_offset + element_index;
          |  if(element_p->index != element_index){
          |      rb_raise(rodException(), "Join element indices are inconsistent: %lu %lu!",
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
          |  _polymorphic_join_element * element_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  element_p = model_p->_polymorphic_join_element_table + element_offset + element_index;
          |  if(element_p->index != element_index){
          |      rb_raise(rodException(), "Polymorphic join element indices are inconsistent: %lu %lu!",
          |        element_index, element_p->index);
          |  }
          |  element_p->offset = offset;
          |  element_p->class = class_id;
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |unsigned long _allocate_join_elements(unsigned long size, VALUE handler){
          |  _join_element * element;
          |  unsigned long index;
          |  #{model_struct} * model_p;
          |  unsigned long result;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  result = model_p->_join_element_count;
          |  for(index = 0; index < size; index++){
          |    if((model_p->_join_element_count + 1) * sizeof(_join_element) >=
          |      page_size() * model_p->_join_element_page_count){
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
          |unsigned long _allocate_polymorphic_join_elements(unsigned long size, VALUE handler){
          |  _polymorphic_join_element * element;
          |  unsigned long index;
          |  #{model_struct} * model_p;
          |  unsigned long result;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  result = model_p->_polymorphic_join_element_count;
          |  for(index = 0; index < size; index++){
          |    if((model_p->_polymorphic_join_element_count + 1) *
          |      sizeof(_polymorphic_join_element) >=
          |      page_size() * model_p->_polymorphic_join_element_page_count){
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
          |  char * str;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  str = model_p->#{StringElement.struct_name}_table + offset;
          |  return rb_str_new(str, length);
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |// The first argument is the string to be stored.
          |// The return value is a pair: length and offset.
          |VALUE _set_string(VALUE ruby_value, VALUE handler){
          |  #{model_struct} * model_p;
          |  unsigned long length = RSTRING_LEN(ruby_value);
          |  char * value = RSTRING_PTR(ruby_value);
          |  unsigned long string_offset, page_offset, current_page, sum;
          |  char * dest;
          |  // table:
          |  // - address of the first page
          |  // page_count:
          |  // - during write - number of allocated pages
          |  // count:
          |  // - total number of bytes
          |  long length_left = length;
          |  // see the routine description above.
          |  VALUE result;
          |  // get the structure
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |  // first free byte in current page
          |  string_offset = model_p->#{StringElement.struct_name}_count % page_size();
          |  page_offset = model_p->#{StringElement.struct_name}_count / page_size();
          |  current_page = page_offset;
          |  while(length_left > 0){
          |    sum = ((unsigned long)length_left) + string_offset;
          |    if(sum >= page_size()){
          |      \n#{mmap_class(StringElement)}
          |    }
          |    dest = model_p->#{StringElement.struct_name}_table +
          |      current_page * page_size() + string_offset;
          |    if(length_left > page_size()){
          |      memcpy(dest,value,page_size());
          |    } else {
          |      memcpy(dest,value,length_left);
          |    }
          |    value += page_size();
          |    current_page++;
          |    length_left -= page_size();
          |  }
          |
          |  model_p->#{StringElement.struct_name}_count += length;
          |
          |  result = rb_ary_new();
          |  rb_ary_push(result, ULONG2NUM(length));
          |  rb_ary_push(result, ULONG2NUM(string_offset + page_offset * page_size()));
          |  return result;
          |}
          END
          builder.c(str.margin)

          #########################################
          # Object accessors
          #########################################
          classes.each do |klass|
            self.class.field_reader("#{klass.struct_name}_count",
                                    "unsigned long",builder,model_struct)
            self.class.field_writer("#{klass.struct_name}_count",
                                    "unsigned long",builder,model_struct)
            self.class.field_reader("#{klass.struct_name}_page_count",
                                    "unsigned long",builder,model_struct)
            self.class.field_writer("#{klass.struct_name}_page_count",
                                    "unsigned long",builder,model_struct)
          end

          #########################################
          # Storage
          #########################################
          classes.each do |klass|
            next if special_class?(klass)
            str =<<-END
            |// Store the object in the database.
            |void _store_#{klass.struct_name}(VALUE object, VALUE handler){
            |
            |  #{model_struct} * model_p;
            |  #{klass.struct_name} * struct_p;
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  if((model_p->#{klass.struct_name}_count+1) * sizeof(#{klass.struct_name}) >=
            |    model_p->#{klass.struct_name}_page_count * page_size()){
            |     \n#{mmap_class(klass)}
            |  }
            |  struct_p = model_p->#{klass.struct_name}_table +
            |    model_p->#{klass.struct_name}_count;
            |  //printf("struct assigned\\n");
            |  model_p->#{klass.struct_name}_count++;
            |
            |  //the number is incresed by 1, because 0 indicates that the
            |  //(referenced) object is nil
            |  struct_p->rod_id = model_p->#{klass.struct_name}_count;
            |  rb_iv_set(object, \"@rod_id\",ULONG2NUM(struct_p->rod_id));
            |}
            END
            builder.c(str.margin)
          end

          #########################################
          # init handler
          #########################################
          str = <<-END
          |VALUE _init_handler(char * dir_path){
          |  #{model_struct} * model_p;
          |  VALUE cClass;
          |  model_p = ALLOC(#{model_struct});
          |
          |  #{init_structs(classes)}
          |
          |  // set dir path
          |  model_p->path = malloc(sizeof(char)*(strlen(dir_path)+1));
          |  strcpy(model_p->path,dir_path);
          |
          |  //create the wrapping object
          |  cClass = rb_define_class("#{model_struct_name(path).camelcase(true)}",
          |    rb_cObject);
          |  return Data_Wrap_Struct(cClass, 0, free, model_p);
          |}
          END
          builder.c(str.margin)

          #########################################
          # create
          #########################################
          str = <<-END
          |void _create(VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |
          |  //mmap the structures
          |  \n#{classes.map{|klass| mmap_class(klass)}.join("\n|\n")}
          |}
          END
          builder.c(str.margin)

          #########################################
          # open
          #########################################
          str =<<-END
          |void _open(VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |
          |  \n#{classes.map do |klass|
             <<-SUBEND
             |  model_p->#{klass.struct_name}_lib_file = -1;
             |  if(model_p->#{klass.struct_name}_page_count > 0){
             |    \n#{open_class_file(klass)}
             |    if((model_p->#{klass.struct_name}_table = mmap(NULL,
             |      model_p->#{klass.struct_name}_page_count * page_size(), PROT_WRITE | PROT_READ,
             |      MAP_SHARED, model_p->#{klass.struct_name}_lib_file, 0)) == MAP_FAILED){
             |      perror(NULL);
             |      rb_raise(rodException(),"Could not mmap class '#{klass}'.");
             |    }
             |  #{update_pointer(klass) unless special_class?(klass)}
             |  } else {
             |    #{mmap_class(klass)}
             |  }
             SUBEND
          end.join("\n")}
          |}
          END
          builder.c(str.margin)

          #########################################
          # close
          #########################################
          str =<<-END
          |// if +classes+ are Qnil, the DB was open in readonly mode.
          |void _close(VALUE handler){
          |  #{model_struct} * model_p;
          |  Data_Get_Struct(handler,#{model_struct},model_p);
          |
          |  \n#{classes.map do |klass|
            <<-SUBEND
            |  if(model_p->#{klass.struct_name}_table != NULL){
            |    if(munmap(model_p->#{klass.struct_name}_table,
            |      page_size() * model_p->#{klass.struct_name}_page_count) == -1){
            |      rb_raise(rodException(),"Could not unmap #{klass.struct_name}.");
            |    }
            |  }
            |  if(close(model_p->#{klass.struct_name}_lib_file) == -1){
            |    rb_raise(rodException(),"Could not close model file for #{klass}.");
            |  }
            SUBEND
          end.join("\n")}
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

          str =<<-END
          |unsigned int _page_size(){
          |  return page_size();
          |}
          END
          builder.c(str.margin)

          if @@rod_development_mode
            # This method is created to force rebuild of the C code, since
            # it is rebuild on the basis of methods' signatures change.
            builder.c_singleton("void __unused_method_#{rand(1000000)}(){}")
          end

          # This has to be at the very end of builder definition!
          self.instance_variable_set("@inline_library",builder.so_name)

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

    def self.rod_exception
      str =<<-END
      |VALUE rodException(){
      |  VALUE klass = rb_const_get(rb_cObject, rb_intern("Rod"));
      |  klass = rb_const_get(klass, rb_intern("DatabaseError"));
      |  return klass;
      |}
      END
      str.margin
    end
  end
end
