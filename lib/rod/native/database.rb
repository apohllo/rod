require 'rod/constants'
require 'rod/database/base'

module Rod
  module Native
    # This class implements (in C) the Database abstraction defined
    # in Rod::Database::Base.
    #
    # Instance of the class should not be used *as* the database (i.e.
    # not in the macro-style function Rod::Model::Resource#database_class).
    # A user should strongly consider subclassing it, since refraining
    # from doing that, will not allow to use different databases for different
    # models simultaneously. This is due to the way RubyInline creates and
    # names (after the name of the class) the C code.
    class Database < ::Rod::Database::Base
      protected

      ## Helper methods printing some generated code ##

      def model_struct_name(path)
        "model_" + path.gsub(/\W/,"_").squeeze("_")
      end

      # Initializes the C structures, which are based on the classes.
      def init_structs(classes)
        Utils.remove_margin(classes.map do |klass|
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
        end.join("\n"))
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
        |      open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP);
        |    if(model_p->#{klass.struct_name}_lib_file == -1) {
        |      rb_raise(rodException(),"Could not open file for class #{klass} on path %s writing.",path);
        |    }
        |    free(path);
        |  }
        END
        Utils.remove_margin(str)
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
        Utils.remove_margin(str)
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
        |  // increase the pages count by numer of pages allocated at-once
        |  model_p->#{klass.struct_name}_page_count += 1;
        |  {
        |    // open the file for writing
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
        |    if(write(model_p->#{klass.struct_name}_lib_file,model_p->empty_data,
        |      page_size()) == -1){
        |      rb_raise(rodException(),"Could not write to file for #{klass.struct_name}.");
        |    }
        |
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
        Utils.remove_margin(str)
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

      # Allocates the space for the +klass+ in the data file.
      def allocate_space(klass)
        empty_data = "\0" * _page_size
        File.open(klass.path_for_data(@path),"w") do |out|
          send("_#{klass.struct_name}_page_count",@handler).
            times{|i| out.print(empty_data)}
        end
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
            builder.include '<sys/stat.h>'
            builder.prefix(Index::HashIndex.endianess)
            builder.include '<stdint.h>'
            classes.each do |klass|
              builder.prefix(klass.typedef_struct)
            end

            builder.prefix("const ALLOCATED_PAGES = 25;")

            str =<<-END
            |unsigned int page_size(){
            |  return sysconf(_SC_PAGE_SIZE) * ALLOCATED_PAGES;
            |}
            END
            builder.prefix(Utils.remove_margin(str))

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
              |  // chunk written to extend file
              |  char * empty_data;
              |
              |} #{model_struct};
            END
            builder.prefix(Utils.remove_margin(str))

            str =<<-END
            |// Deallocates the model struct.
            |void model_struct_free(#{model_struct} * model_p){
            |  if(model_p != NULL){
            |    if(model_p->path != NULL){
            |      // TODO causes segfault
            |      //printf("GC %lu %lu\\n",(unsigned long)model_p,
            |      // (unsigned long)model_p->path);
            |      //free(model_p->path);
            |      model_p->path = NULL;
            |    }
            |    if(model_p->empty_data != NULL){
            |      //free(model_p->empty_data);
            |      model_p->empty_data = NULL;
            |    }
            |  }
            |  free(model_p);
            |}
            END
            builder.prefix(Utils.remove_margin(str))


            #########################################
            # Join indices
            #########################################
            str =<<-END
            |VALUE _join_element_index(unsigned long element_offset, unsigned long element_index, VALUE handler){
            |  #{model_struct} * model_p;
            |  unsigned long result;
            |
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  result = (model_p->_join_element_table + element_offset + element_index)->offset;
            |#ifdef __BYTE_ORDER
            |#  if __BYTE_ORDER == __BIG_ENDIAN
            |  result = bswap_64(result);
            |#  endif
            |#endif
            |  return ULONG2NUM(result);
            |}
            END
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |VALUE _polymorphic_join_element_index(unsigned long element_offset,
            |  unsigned long element_index, VALUE handler){
            |  #{model_struct} * model_p;
            |  unsigned long result;
            |
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  result = (model_p->_polymorphic_join_element_table +
            |    element_offset + element_index)->offset;
            |#ifdef __BYTE_ORDER
            |#  if __BYTE_ORDER == __BIG_ENDIAN
            |  result = bswap_64(result);
            |#  endif
            |#endif
            |  return ULONG2NUM(result);
            |}
            END
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |VALUE _polymorphic_join_element_class(unsigned long element_offset,
            |  unsigned long element_index, VALUE handler){
            |  #{model_struct} * model_p;
            |  unsigned long result;
            |
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  result = (model_p->_polymorphic_join_element_table +
            |    element_offset + element_index)->class;
            |#ifdef __BYTE_ORDER
            |#  if __BYTE_ORDER == __BIG_ENDIAN
            |  result = bswap_64(result);
            |#  endif
            |#endif
            |  return ULONG2NUM(result);
            |}
            END
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |void _set_join_element_offset(unsigned long element_offset,
            |  unsigned long element_index, unsigned long offset,
            |  VALUE handler){
            |  #{model_struct} * model_p;
            |  _join_element * element_p;
            |
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  element_p = model_p->_join_element_table + element_offset + element_index;
            |  if(element_p->index != element_index){
            |      rb_raise(rodException(), "Join element indices are inconsistent: %lu %lu!",
            |        element_index, element_p->index);
            |  }
            |#ifdef __BYTE_ORDER
            |#  if __BYTE_ORDER == __BIG_ENDIAN
            |  offset = bswap_64(offset);
            |#  endif
            |#endif
            |  element_p->offset = offset;
            |}
            END
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |void _set_polymorphic_join_element_offset(unsigned long element_offset,
            |  unsigned long element_index, unsigned long offset, unsigned long class_id,
            |  VALUE handler){
            |  #{model_struct} * model_p;
            |  _polymorphic_join_element * element_p;
            |
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  element_p = model_p->_polymorphic_join_element_table + element_offset + element_index;
            |  if(element_p->index != element_index){
            |      rb_raise(rodException(), "Polymorphic join element indices are inconsistent: %lu %lu!",
            |        element_index, element_p->index);
            |  }
            |#ifdef __BYTE_ORDER
            |#  if __BYTE_ORDER == __BIG_ENDIAN
            |  offset = bswap_64(offset);
            |  class_id = bswap_64(class_id);
            |#  endif
            |#endif
            |  element_p->offset = offset;
            |  element_p->class = class_id;
            |}
            END
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |unsigned long _allocate_join_elements(unsigned long size, VALUE handler){
            |  _join_element * element;
            |  unsigned long index;
            |  #{model_struct} * model_p;
            |  unsigned long result;
            |
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  result = model_p->_join_element_count;
            |  for(index = 0; index < size; index++){
            |    if((model_p->_join_element_count + 1) * sizeof(_join_element) >=
            |      page_size() * model_p->_join_element_page_count){
            |      \n#{mmap_class(Model::JoinElement)}
            |    }
            |    element = model_p->_join_element_table + model_p->_join_element_count;
            |    model_p->_join_element_count++;
            |    element->index = index;
            |    element->offset = 0;
            |  }
            |  return result;
            |}
            END
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |unsigned long _allocate_polymorphic_join_elements(unsigned long size, VALUE handler){
            |  _polymorphic_join_element * element;
            |  unsigned long index;
            |  #{model_struct} * model_p;
            |  unsigned long result;
            |
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  result = model_p->_polymorphic_join_element_count;
            |  for(index = 0; index < size; index++){
            |    if((model_p->_polymorphic_join_element_count + 1) *
            |      sizeof(_polymorphic_join_element) >=
            |      page_size() * model_p->_polymorphic_join_element_page_count){
            |      \n#{mmap_class(Model::PolymorphicJoinElement)}
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
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |VALUE _fast_intersection_size(unsigned long first_offset,
            |  unsigned long first_length, unsigned long second_offset,
            |  unsigned long second_length, VALUE handler){
            |  unsigned long i,j,count,v1,v2;
            |  #{model_struct} * model_p;
            |
            |  i = 0; j = 0; count = 0;
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |
            |  while(i < first_length && j < second_length){
            |    v1 = (model_p->_join_element_table + first_offset + i)->offset;
            |    v2 = (model_p->_join_element_table + second_offset + j)->offset;
            |#ifdef __BYTE_ORDER
            |#  if __BYTE_ORDER == __BIG_ENDIAN
            |    v1 = bswap_64(v1);
            |    v2 = bswap_64(v2);
            |#  endif
            |#endif
            |    if(v1 < v2){
            |      i++;
            |    } else {
            |      if(v1 > v2){
            |        j++;
            |      } else {
            |        i++; j++; count++;
            |      }
            |    }
            |  }
            |  return ULONG2NUM(count);
            |}
            END
            builder.c(Utils.remove_margin(str))

            #########################################
            # Strings
            #########################################
            str =<<-END
            |VALUE _read_string(unsigned long length, unsigned long offset, VALUE handler){
            |  #{model_struct} * model_p;
            |  char * str;
            |
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  str = model_p->#{Model::StringElement.struct_name}_table + offset;
            |  return rb_str_new(str, length);
            |}
            END
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |// The first argument is the string to be stored.
            |// The return value is a pair: length and offset.
            |VALUE _set_string(VALUE ruby_value, VALUE handler){
            |  #{model_struct} * model_p;
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
            |  // see the routine description above.
            |  VALUE result;
            |
            |  // get the structure
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  // first free byte in current page
            |  string_offset = model_p->#{Model::StringElement.struct_name}_count % page_size();
            |  page_offset = model_p->#{Model::StringElement.struct_name}_count / page_size();
            |  current_page = page_offset;
            |  while(length_left > 0){
            |    if(((unsigned long)length_left) + string_offset >= page_size()){
            |      \n#{mmap_class(Model::StringElement)}
            |    }
            |    dest = model_p->#{Model::StringElement.struct_name}_table +
            |      current_page * page_size() + string_offset;
            |    if(((unsigned long)length_left) > page_size()){
            |      memcpy(dest,value,page_size());
            |    } else {
            |      memcpy(dest,value,length_left);
            |    }
            |    value += page_size();
            |    current_page++;
            |    length_left -= page_size();
            |  }
            |
            |  model_p->#{Model::StringElement.struct_name}_count += length;
            |
            |  result = rb_ary_new();
            |  rb_ary_push(result, ULONG2NUM(length));
            |  rb_ary_push(result, ULONG2NUM(string_offset + page_offset * page_size()));
            |  return result;
            |}
            END
            builder.c(Utils.remove_margin(str))

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
              |  #{model_struct} * model_p;
              |  #{klass.struct_name} * struct_p;
              |
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
              builder.c(Utils.remove_margin(str))
            end

            #########################################
            # init handler
            #########################################
            str = <<-END
            |VALUE _init_handler(char * dir_path){
            |  #{model_struct} * model_p;
            |  VALUE cClass;
            |
            |  model_p = ALLOC(#{model_struct});
            |  #{init_structs(classes)}
            |
            |  // set dir path
            |  model_p->path = malloc(sizeof(char)*(strlen(dir_path)+1));
            |  strcpy(model_p->path,dir_path);
            |
            |  // initialize empty data written when extending file
            |  model_p->empty_data = calloc(page_size(),1);
            |
            |  //create the wrapping object
            |  cClass = rb_define_class("#{model_struct_name(path).camelcase(true)}",
            |    rb_cObject);
            |  // TODO #225
            |  //return Data_Wrap_Struct(cClass, 0, model_struct_free, model_p);
            |  return Data_Wrap_Struct(cClass, 0, free, model_p);
            |}
            END
            builder.c(Utils.remove_margin(str))

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
            builder.c(Utils.remove_margin(str))

            #########################################
            # open
            #########################################
            str =<<-END
            |void _open(VALUE handler){
            |  #{model_struct} * model_p;
            |
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
            builder.c(Utils.remove_margin(str))

            #########################################
            # close
            #########################################
            str =<<-END
            |// if +classes+ are Qnil, the DB was open in readonly mode.
            |void _close(VALUE handler){
            |  #{model_struct} * model_p;
            |
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
            builder.c(Utils.remove_margin(str))


            #########################################
            # Utilities
            #########################################
            str = <<-END
            |void _print_layout(VALUE handler){
            |  #{model_struct} * model_p;
            |
            |  Data_Get_Struct(handler,#{model_struct},model_p);
            |  printf("============= Data layout START =============\\n");
            |  \n#{classes.map do |klass|
                 str =<<-SUBEND
            |  printf("-- #{klass} --\\n");
            |  printf("Size of #{klass.struct_name} %lu\\n",(unsigned long)sizeof(#{klass.struct_name}));
            |  printf("Page count: %lu, count %lu, pointer: %lx\\n",
            |    model_p->#{klass.struct_name}_page_count,
            |    model_p->#{klass.struct_name}_count,
            |    (unsigned long)model_p->#{klass.struct_name}_table);
                 SUBEND
                 Utils.remove_margin(str)
               end.join("\n")}
            |  printf("============= Data layout END =============\\n");
            |}
            END
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |void _print_system_error(){
            |  perror(NULL);
            |}
            END
            builder.c(Utils.remove_margin(str))

            str =<<-END
            |unsigned int _page_size(){
            |  return page_size();
            |}
            END
            builder.c(Utils.remove_margin(str))

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
        |
        |  Data_Get_Struct(handler,#{model_struct},model_p);
        |  return model_p->#{name};
        |}
        END
        builder.c(Utils.remove_margin(str))
      end

      # Writes the value of a specified field of the C-structure.
      def self.field_writer(name,arg_type,builder,model_struct)
        str =<<-END
        |void _#{name}_equals(VALUE handler,#{arg_type} value){
        |  #{model_struct} * model_p;
        |
        |  Data_Get_Struct(handler,#{model_struct},model_p);
        |  model_p->#{name} = value;
        |}
        END
        builder.c(Utils.remove_margin(str))
      end

      def self.rod_exception
        str =<<-END
        |VALUE rodException(){
        |  VALUE klass;
        |
        |  klass = rb_const_get(rb_cObject, rb_intern("Rod"));
        |  klass = rb_const_get(klass, rb_intern("DatabaseError"));
        |  return klass;
        |}
        END
        Utils.remove_margin(str)
      end
    end
  end
end
