# encoding: utf-8
require 'inline'
require 'rod/utils'

module Rod
  module Native
    # This class is reponsible for writing and reading basic
    # values (int, ulong, float) from the storage device.
    class RawDatabase
      # The mapping of storage function names to the C types.
      TYPES = {"integer" => "int", "float" => "double", "ulong" => "unsigned long"}

      # The path where the database stores the data.
      attr_reader :path

      # Initialize this database with given +path+, +element_size+
      # and +element_count+.
      #
      # The database consists of elements of the same size and the same
      # structure. These elements are indexed from 0. The internal
      # structure of the elements is unknown to the database.
      #
      # The elements consists of fields converted to uint64_t type.
      # The size of an element and the offset of a property is
      # expressed using this type's size as a unit.
      #
      # The +readonly+ option indicates if the database
      # is opened in readonly state.
      def initialize(path,element_size,element_count,readonly=true)
        raise InvalidArgument.new(path,"path") unless String === path
        raise InvalidArgument.new(element_size,"element_size") unless Fixnum === element_size
        raise InvalidArgument.new(element_size,"element_size") if element_size < 0
        raise InvalidArgument.new(element_count,"element_count") unless Fixnum === element_count
        raise InvalidArgument.new(element_count,"element_count") if element_count < 0

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

        _init(path,page_count,element_size,element_count)
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

      # Close the database.
      def close
        _close()
        @opened = false
      end

      # Save the integer +value+ in the database at +element_offset+
      # with +property_offset+.
      #
      # Storing of integers is limited by the architecture of the system.
      # The maximum value that might be stored is the maximum value of
      # Fixnum. However the data with larger values is portable accross systems
      # with different architecture (due to automatic conversion to Bignum).
      def save_integer(element_offset,property_offset,value)
        raise InvalidArgument.new(value,"integer") unless Fixnum === value
        check_save_state()
        check_offsets(element_offset,property_offset)
        _save_integer(element_offset,property_offset,value)
      end

      # Save the integer +value+ from the database at +element_offset+
      # with +property_offset+.
      def read_integer(element_offset,property_offset)
        check_read_state()
        check_offsets(element_offset,property_offset)
        _read_integer(element_offset,property_offset)
      end

      # Save the unsgined long +value+ in the database at +element_offset+
      # with +property_offset+.
      def save_ulong(element_offset,property_offset,value)
        raise InvalidArgument.new(value,"ulong") unless Integer === value
        raise InvalidArgument.new(value,"ulong") unless value >= 0
        check_save_state()
        check_offsets(element_offset,property_offset)
        _save_ulong(element_offset,property_offset,value)
      end

      # Save the unsigned long +value+ from the database at +element_offset+
      # with +property_offset+.
      def read_ulong(element_offset,property_offset)
        check_read_state()
        check_offsets(element_offset,property_offset)
        _read_ulong(element_offset,property_offset)
      end

      # Save the float +value+ in the database at +element_offset+
      # with +property_offset+.
      def save_float(element_offset,property_offset,value)
        raise InvalidArgument.new(value,"float") unless Numeric === value
        check_save_state()
        check_offsets(element_offset,property_offset)
        _save_float(element_offset,property_offset,value)
      end

      # Save the float +value+ from the database at +element_offset+
      # with +property_offset+.
      def read_float(element_offset,property_offset)
        check_read_state()
        check_offsets(element_offset,property_offset)
        _read_float(element_offset,property_offset)
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
        # The definition of the database struct.
        def struct
          str =<<-END
          |typedef struct raw_database_struct {
          |  uint64_t *     data;
          |  char *         empty_data;
          |  int            file;
          |  size_t         page_count;
          |  size_t         element_size;
          |  unsigned long  element_count;
          |  char *         path;
          |} raw_database;
          END
          Utils.remove_margin(str)
        end

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
      end

      inline(:C) do |builder|
        builder.include '<stdlib.h>'
        builder.include '<stdio.h>'
        builder.include '<string.h>'
        builder.include '<fcntl.h>'
        builder.include '<unistd.h>'
        builder.include '<errno.h>'
        builder.include '<sys/mman.h>'
        builder.include '<sys/stat.h>'
        builder.include '<byteswap.h>'
        builder.include '<endian.h>'
        builder.include '<stdint.h>'
        builder.prefix(struct)
        builder.prefix(database_error)

        str =<<-END
        |/*
        |* Create the data file unless it exists. Then assign
        |* the file handle to the database struct.
        |*/
        |static void open_file(VALUE self){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
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
        builder.prefix(Utils.remove_margin(str))

        builder.prefix("const ALLOCATED_PAGES = 25;")

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
        builder.prefix(Utils.remove_margin(str))

        str =<<-END
        |static void unmap_data(raw_database * database){
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
        builder.prefix(Utils.remove_margin(str))

        str =<<-END
        |static void close_file(raw_database * database){
        |  if(database->file != -1) {
        |    if(close(database->file) == -1){
        |      database->file = -1;
        |      rb_raise(database_error(),"Could not close file %s.",database->path);
        |    }
        |  }
        |  database->file = -1;
        |}
        END
        builder.prefix(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Free the database struct.
        |*/
        |static void free_database(raw_database * database){
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
        builder.prefix(Utils.remove_margin(str))


        str =<<-END
        |static void grow_file(VALUE self){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
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
        builder.prefix(Utils.remove_margin(str))

        str =<<-END
        |static void map_data(VALUE self){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
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
        builder.prefix(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Replaces default allocate with function returning wrapper for the
        |* database struct.
        |*/
        |VALUE allocate(){
        |  raw_database * database;
        |  database = ALLOC(raw_database);
        |  database->data = NULL;
        |  database->file = -1;
        |  database->empty_data = calloc(page_size(),1);
        |  database->path = NULL;
        |  database->page_count = 0;
        |  // db_mark == NULL - no internal elements have to be marked
        |  return Data_Wrap_Struct(self,NULL,free_database,database);
        |}
        END
        builder.c_singleton(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Opens the database on the +path+.
        |*/
        |void _init(char * path, unsigned int page_count, unsigned int element_size,
        |           unsigned long element_count){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
        |  database->path = malloc(strlen(path)+1);
        |  strcpy(database->path,path);
        |  database->page_count = page_count;
        |  database->element_size = element_size;
        |  database->element_count = element_count;
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Returns the size of data page.
        |*/
        |unsigned int _page_size(){
        |  return page_size();
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Opens the database on the +path+.
        |*/
        |void _open(){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
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
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Closes the database.
        |*/
        |void _close(){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
        |  unmap_data(database);
        |  close_file(database);
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Returns the path of the database.
        |*/
        |const char * _path(){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
        |  return database->path;
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Returns the number of elements allocated in the database.
        |*/
        |unsigned long _element_count(){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
        |  return database->element_count;
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Updates the number of element allocated in the database.
        |*/
        |void _element_count_equals(unsigned long value){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
        |  database->element_count = value;
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Returns the number of allocated data pages.
        |*/
        |unsigned long _page_count(){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
        |  return database->page_count;
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Updates the number of allocated data pages.
        |*/
        |void _page_count_equals(unsigned int value){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
        |  database->page_count = value;
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Returns the size of elements in the database.
        |*/
        |unsigned long _element_size(){
        |  raw_database * database;
        |
        |  Data_Get_Struct(self,raw_database,database);
        |  return database->element_size;
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Allocates the space for new elements.
        |*/
        |void _allocate_elements(unsigned long count){
        |  raw_database * database;
        |  unsigned long allocated_elements_count;
        |  unsigned long elements_left;
        |
        |  Data_Get_Struct(self,raw_database,database);
        |  elements_left = count;
        |  while((elements_left + database->element_count) *
        |       database->element_size * 8 >=
        |       database->page_count * page_size()){
        |    unmap_data(database);
        |    grow_file(self);
        |    map_data(self);
        |    allocated_elements_count = (database->page_count * page_size()) /
        |                                 (database->element_size * 8) -
        |                               ((database->page_count-1) * page_size()) /
        |                                 (database->element_size * 8);
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
        builder.c(Utils.remove_margin(str))

        TYPES.each do |name,cname|
          str =<<-END
          |/*
          |* Save a(n) #{name} to the database.
          |*/
          |void _save_#{name}(unsigned long element_offset,unsigned long property_offset,
          |       #{cname} value){
          |  raw_database * database;
          |  uint64_t as_uint;
          |
          |  as_uint = *((uint64_t *)((char *)&value));
          |
          |#ifdef __BYTE_ORDER
          |#  if __BYTE_ORDER == __BIG_ENDIAN
          |  // TODO #220 #221
          |  as_uint = bswap_64(as_uint);
          |#  endif
          |#endif
          |
          |  Data_Get_Struct(self,raw_database,database);
          |  database->data[element_offset*database->element_size+property_offset] =
          |    as_uint;
          |}
          END
          builder.c(Utils.remove_margin(str))

          str =<<-END
          |/*
          |* Read a(n) #{name} from the database.
          |*/
          |#{cname} _read_#{name}(unsigned long element_offset,
          |                       unsigned long property_offset){
          |  raw_database * database;
          |  uint64_t as_uint;
          |
          |  Data_Get_Struct(self,raw_database,database);
          |
          |  as_uint = database->data[element_offset*database->element_size+property_offset];
          |#ifdef __BYTE_ORDER
          |#  if __BYTE_ORDER == __BIG_ENDIAN
          |  // TODO #220 #221
          |  as_uint = bswap_64(*((uint64_t *)((char *)&as_uint)));
          |#  endif
          |#endif
          |  return *(#{cname} *)((char *)&as_uint);
          |}
          END
          builder.c(Utils.remove_margin(str))
        end
      end

      protected
      # Checks if the +element_offset+ and the +property_offset+ are valid.
      # Throws invalid argument exception if they are not valid.
      def check_offsets(element_offset,property_offset)
        if element_offset >= _element_count || element_offset < 0
          raise InvalidArgument.new(element_offset,"element offset")
        end
        if property_offset >= _element_size || property_offset < 0
          raise InvalidArgument.new(property_offset,"property offset")
        end
      end

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
