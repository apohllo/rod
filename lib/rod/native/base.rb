# encoding: utf-8
require 'inline'
require 'rod/utils'

module Rod
  module Native
    # This class is a base clase for native databases.
    class Base
      # The path where the database stores the data.
      attr_reader :path

      # Initialize this database with given +path+.
      #
      # The +readonly+ option indicates if the database
      # is opened in readonly state.
      #
      # The value returned is the number of pages allocated in the DB file.
      def initialize(path,readonly)
        raise InvalidArgument.new(path,"path") unless String === path

        @opened = false
        @readonly = readonly

        # Check if the database file exist. If it exists, set the
        # page_count accordingly.
        if File.exist?(path)
          file_size = File.size(path)
          unless file_size % _page_size == 0
            raise DatabaseError.new("Size of data file #{path} is invalid: #{file_size}")
          end
          page_count = file_size / _page_size
        else
          page_count = 0
        end
      end

      # Returns true if the database was opened, i.e. values might
      # be saved and read from it.
      def opened?
        @opened
      end

      # Returns true if the database is/will be opened in readonly state.
      def readonly?
        @readonly
      end

      # Close the database.
      def close
        _close()
        @opened = false
      end

      # Open the database. If block is given, the database is automatically
      # closed when the processing inside the block is finished. This
      # also holds if an exception is thrown inside the block.
      # Options:
      # * +:truncate+ - if true, the database is truncated, i.e. all data are removed
      #   (false by default)
      def open(options={})
        if block_given?
          begin
            open(options)
            yield
          ensure
            close
          end
        else
          raise DatabaseError.new("Database already opened.") if opened?
          truncate = options[:truncate] || false
          if truncate
            raise DatabaseError.new("Database is readonly.") if readonly?
            if File.exist?(_path)
              Utils.remove_file(_path)
            end
            self._page_count = 0
            remembered_element_count = self._element_count
            self._element_count = 0
          end
          _open()
          @opened = true
          allocate_elements(remembered_element_count) if truncate
        end
      end

      # Allocates space for +count+ elements. As a result the number
      # of elements is updated (it is equal to the last number of elements
      # plus the number of allocated elements).
      def allocate_elements(count)
        raise InvalidArgument.new(count,"count") unless Fixnum === count
        raise InvalidArgument.new(count,"count") if count < 0
        check_save_state
        _allocate_elements(count)
      end

      class << self
        # The DatabaseError exception.
        def database_error
          str =<<-END
          |VALUE database_error(){
          |  VALUE klass;
          |
          |  klass = rb_const_get(rb_cObject, rb_intern("Rod"));
          |  klass = rb_const_get(klass, rb_intern("DatabaseError"));
          |  return klass;
          |}
          END
          Utils.remove_margin(str)
        end

        # The definition of close method.
        def close_definition
          str =<<-END
          |/*
          |* Closes the database.
          |*/
          |void _close(){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  unmap_data(database);
          |  close_file(database);
          |}
          END
          Utils.remove_margin(str)
        end

        def unmap_data_definition
          str =<<-END
          |static void unmap_data(database_struct * database){
          |  if(database->data != NULL){
          |    if(munmap(database->data,page_size()*database->page_count) == -1){
          |      perror(NULL);
          |      database->data = NULL;
          |      rb_raise(database_error(),"Could not unmap data at %s.",database->path);
          |    }
          |    database->data = NULL;
          |  }
          |}
          END
          Utils.remove_margin(str)
        end

        def close_file_definition
          str =<<-END
          |static void close_file(database_struct * database){
          |  if(database->file != -1) {
          |    if(close(database->file) == -1){
          |      database->file = -1;
          |      rb_raise(database_error(),"Could not close file %s.",database->path);
          |    }
          |  }
          |  database->file = -1;
          |}
          END
          Utils.remove_margin(str)
        end

        def path_definition
          str =<<-END
          |/*
          |* Returns the path of the database.
          |*/
          |const char * _path(){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  return database->path;
          |}
          END
          Utils.remove_margin(str)
        end

        def open_definition
          str =<<-END
          |/*
          |* Opens the database on the +path+.
          |*/
          |void _open(){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |
          |  if(database->page_count > 0){
          |    open_file(self);
          |    map_data(self);
          |  } else {
          |    open_file(self);
          |    grow_file(self);
          |    map_data(self);
          |  }
          |}
          END
          Utils.remove_margin(str)
        end

        def map_data_definition
          str =<<-END
          |static void map_data(VALUE self){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |
          |  database->data = mmap(NULL, database->page_count * page_size(),
          |    PROT_WRITE | PROT_READ, MAP_SHARED, database->file,0);
          |  if(database->data == MAP_FAILED){
          |    perror(NULL);
          |    database->data = NULL;
          |    rb_raise(database_error(),"Could not mmap data at path %s.",database->path);
          |  }
          |}
          END
          Utils.remove_margin(str)
        end

        def open_file_definition
          str =<<-END
          |/*
          |* Create the data file unless it exists. Then assign
          |* the file handle to the database struct.
          |*/
          |static void open_file(VALUE self){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  if(database-> file == -1){
          |    database->file =
          |      open(database->path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR |
          |        S_IRGRP | S_IWGRP);
          |    if(database->file == -1) {
          |      rb_raise(database_error(),"Could not open file on path %s for writing.",
          |        database->path);
          |    }
          |  }
          |}
          END
          Utils.remove_margin(str)
        end

        def page_count_definition
          str =<<-END
          |/*
          |* Returns the number of allocated data pages.
          |*/
          |unsigned long _page_count(){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  return database->page_count;
          |}
          END
          Utils.remove_margin(str)
        end

        def page_count_equals_definition
          str =<<-END
          |/*
          |* Updates the number of allocated data pages.
          |*/
          |void _page_count_equals(unsigned int value){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  database->page_count = value;
          |}
          END
          Utils.remove_margin(str)
        end

        def element_count_definition
          str =<<-END
          |/*
          |* Returns the number of elements allocated in the database.
          |*/
          |unsigned long _element_count(){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  return database->element_count;
          |}
          END
          Utils.remove_margin(str)
        end

        def element_count_equals_definition
          str =<<-END
          |/*
          |* Updates the number of element allocated in the database.
          |*/
          |void _element_count_equals(unsigned long value){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  database->element_count = value;
          |}
          END
          Utils.remove_margin(str)
        end

        def page_size_definition
          str =<<-END
          |/*
          |* Return the size of one page of data. It might be larger
          |* than the memory page, since due to performance reasons
          |* we allocate many memory pages at once.
          |*/
          |static unsigned int page_size(){
          |  return sysconf(_SC_PAGE_SIZE) * ALLOCATED_PAGES;
          |}
          END
          Utils.remove_margin(str)
        end

        def grow_file_definition
          str =<<-END
          |static void grow_file(VALUE self){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |
          |  // increase the number of allocated (data) pages
          |  database->page_count += 1;
          |
          |  // open the file for writing
          |  FILE * file = fdopen(database->file,"w+");
          |  if(file == NULL){
          |    rb_raise(database_error(),"Could not open file %s for writing.",database->path);
          |  }
          |  // seek to the end
          |  if(fseek(file,0,SEEK_END) == -1){
          |    rb_raise(database_error(),"Could not seek to the end of file %s.",database->path);
          |  }
          |  // write empty data at the end
          |  if(write(database->file,database->empty_data,page_size()) == -1){
          |    rb_raise(database_error(),"Could not write to file %s.",database->path);
          |  }
          |  // seek to the beginning
          |  if(fseek(file,0,SEEK_SET) == -1){
          |    rb_raise(database_error(),"Could not seek to start of file %s.",database->path);
          |  }
          |}
          END
          Utils.remove_margin(str)
        end

        def page_size_reader_definition
          str =<<-END
          |/*
          |* Returns the size of data page.
          |*/
          |unsigned int _page_size(){
          |  return page_size();
          |}
          END
          Utils.remove_margin(str)
        end

        def allocated_pages_definition
          "const ALLOCATED_PAGES = 25;"
        end

        def free_database_definition
          str =<<-END
          |/*
          |* Free the database struct.
          |*/
          |static void free_database(database_struct * database){
          |  if(database != NULL){
          |    if(database->data != NULL){
          |      unmap_data(database);
          |    }
          |    if(database->empty_data != NULL){
          |      free(database->empty_data);
          |      database->empty_data = NULL;
          |    }
          |    if(database->file != -1){
          |      close_file(database);
          |    }
          |    if(database->path != NULL){
          |      free(database->path);
          |      database->path = NULL;
          |    }
          |    free(database);
          |  }
          |}
          END
          Utils.remove_margin(str)
        end

        def init_definition
          str =<<-END
          |/*
          |* Opens the database on the +path+.
          |*/
          |void _init(char * path, unsigned int page_count, unsigned int element_size,
          |           unsigned int unit_size, unsigned long element_count){
          |  database_struct * database;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  database->path = malloc(strlen(path)+1);
          |  strcpy(database->path,path);
          |  database->page_count = page_count;
          |  database->element_size = element_size;
          |  database->unit_size = unit_size;
          |  database->element_count = element_count;
          |}
          END
          Utils.remove_margin(str)
        end

        def allocate_definition
          str =<<-END
          |/*
          |* Replaces default allocate with function returning wrapper for the
          |* database struct.
          |*/
          |VALUE allocate(){
          |  database_struct * database;
          |  database = ALLOC(database_struct);
          |  database->data = NULL;
          |  database->file = -1;
          |  database->empty_data = calloc(page_size(),1);
          |  database->path = NULL;
          |  database->page_count = 0;
          |  database->element_count = 0;
          |  database->element_size = 0;
          |  // db_mark == NULL - no internal elements have to be marked
          |  return Data_Wrap_Struct(self,NULL,free_database,database);
          |}
          END
          Utils.remove_margin(str)
        end

        def allocate_elements_definition
          str =<<-END
          |/*
          |* Allocates the space for new elements.
          |*/
          |void _allocate_elements(unsigned long count){
          |  database_struct * database;
          |  unsigned long allocated_elements_count;
          |  unsigned long elements_left;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  elements_left = count;
          |  while((elements_left + database->element_count) *
          |       database->element_size * database->unit_size >=
          |       database->page_count * page_size()){
          |    unmap_data(database);
          |    grow_file(self);
          |    map_data(self);
          |    allocated_elements_count = (database->page_count * page_size()) /
          |                                 (database->element_size * database->unit_size) -
          |                               ((database->page_count-1) * page_size()) /
          |                                 (database->element_size * database->unit_size);
          |
          |    if(elements_left >= allocated_elements_count){
          |      database->element_count += allocated_elements_count;
          |      elements_left -= allocated_elements_count;
          |    } else {
          |      break;
          |    }
          |  }
          |  database->element_count += elements_left;
          |}
          END
          Utils.remove_margin(str)
        end
      end

      protected
      # Checks the state of the database for save operation.
      # Throws an exception if the database is in invalid state.
      def check_save_state
        raise DatabaseError.new("Database is closed.") unless opened?
        raise DatabaseError.new("Database is readonly.") if readonly?
      end

      # Checks the state of the database for read operation.
      # Throws an exception if the database is in invalid state.
      def check_read_state
        raise DatabaseError.new("Database is closed.") unless opened?
      end
    end
  end
end
