# encoding: utf-8
require 'inline'
require 'rod/utils'

module Rod
  module Native
    # This class is a base clase for native stores.
    class Store
      # The path where the store stores the data.
      attr_reader :path

      # Initialize this store with given +path+.
      #
      # The +readonly+ option indicates if the store
      # is opened in readonly state.
      #
      # The value returned is the number of pages allocated in the store file.
      def initialize(path,readonly)
        raise InvalidArgument.new(path,"path") unless String === path

        @opened = false
        @readonly = readonly

        # Check if the store file exist. If it exists, set the
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

      # Returns true if the store was opened, i.e. values might
      # be saved and read from it.
      def opened?
        @opened
      end

      # Returns true if the store is/will be opened in readonly state.
      def readonly?
        @readonly
      end

      # Close the store.
      def close
        _close()
        @opened = false
      end

      # Open the store. If block is given, the store is automatically
      # closed when the processing inside the block is finished. This
      # also holds if an exception is thrown inside the block.
      # Options:
      # * +:truncate+ - if true, the store is truncated, i.e. all data are removed
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
        check_write_state
        _allocate_elements(count)
      end

      # Returns the number of (allocated) elements in the store.
      def element_count
        _element_count
      end

      class << self
        # The DatabaseError exception.
        def store_error
          str =<<-END
          |VALUE store_error(){
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
          |* Closes the store.
          |*/
          |void _close(){
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |  unmap_data(store);
          |  close_file(store);
          |}
          END
          Utils.remove_margin(str)
        end

        def unmap_data_definition
          str =<<-END
          |static void unmap_data(store_struct * store){
          |  if(store->data != NULL){
          |    if(munmap(store->data,page_size()*store->page_count) == -1){
          |      perror(NULL);
          |      store->data = NULL;
          |      rb_raise(store_error(),"Could not unmap data at %s.",store->path);
          |    }
          |    store->data = NULL;
          |  }
          |}
          END
          Utils.remove_margin(str)
        end

        def close_file_definition
          str =<<-END
          |static void close_file(store_struct * store){
          |  if(store->file != -1) {
          |    if(close(store->file) == -1){
          |      store->file = -1;
          |      rb_raise(store_error(),"Could not close file %s.",store->path);
          |    }
          |  }
          |  store->file = -1;
          |}
          END
          Utils.remove_margin(str)
        end

        def path_definition
          str =<<-END
          |/*
          |* Returns the path of the store.
          |*/
          |const char * _path(){
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |  return store->path;
          |}
          END
          Utils.remove_margin(str)
        end

        def open_definition
          str =<<-END
          |/*
          |* Opens the store on the +path+.
          |*/
          |void _open(){
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |
          |  if(store->page_count > 0){
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
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |
          |  store->data = mmap(NULL, store->page_count * page_size(),
          |    PROT_WRITE | PROT_READ, MAP_SHARED, store->file,0);
          |  if(store->data == MAP_FAILED){
          |    perror(NULL);
          |    store->data = NULL;
          |    rb_raise(store_error(),"Could not mmap data at path %s.",store->path);
          |  }
          |}
          END
          Utils.remove_margin(str)
        end

        def open_file_definition
          str =<<-END
          |/*
          |* Create the data file unless it exists. Then assign
          |* the file handle to the store struct.
          |*/
          |static void open_file(VALUE self){
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |  if(store-> file == -1){
          |    store->file =
          |      open(store->path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR |
          |        S_IRGRP | S_IWGRP);
          |    if(store->file == -1) {
          |      rb_raise(store_error(),"Could not open file on path %s for writing.",
          |        store->path);
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
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |  return store->page_count;
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
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |  store->page_count = value;
          |}
          END
          Utils.remove_margin(str)
        end

        def element_count_definition
          str =<<-END
          |/*
          |* Returns the number of elements allocated in the store.
          |*/
          |unsigned long _element_count(){
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |  return store->element_count;
          |}
          END
          Utils.remove_margin(str)
        end

        def element_count_equals_definition
          str =<<-END
          |/*
          |* Updates the number of element allocated in the store.
          |*/
          |void _element_count_equals(unsigned long value){
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |  store->element_count = value;
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
          |  store_struct * store;
          |  FILE * file;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |
          |  // increase the number of allocated (data) pages
          |  store->page_count += 1;
          |
          |  // open the file for writing
          |  file = fdopen(store->file,"w+");
          |  if(file == NULL){
          |    rb_raise(store_error(),"Could not open file %s for writing.",store->path);
          |  }
          |  // seek to the end
          |  if(fseek(file,0,SEEK_END) == -1){
          |    rb_raise(store_error(),"Could not seek to the end of file %s.",store->path);
          |  }
          |  // write empty data at the end
          |  if(write(store->file,store->empty_data,page_size()) == -1){
          |    rb_raise(store_error(),"Could not write to file %s.",store->path);
          |  }
          |  // seek to the beginning
          |  if(fseek(file,0,SEEK_SET) == -1){
          |    rb_raise(store_error(),"Could not seek to start of file %s.",store->path);
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
          "const int ALLOCATED_PAGES = 25;"
        end

        def free_store_definition
          str =<<-END
          |/*
          |* Free the store struct.
          |*/
          |static void free_store(store_struct * store){
          |  if(store != NULL){
          |    if(store->data != NULL){
          |      unmap_data(store);
          |    }
          |    if(store->empty_data != NULL){
          |      free(store->empty_data);
          |      store->empty_data = NULL;
          |    }
          |    if(store->file != -1){
          |      close_file(store);
          |    }
          |    if(store->path != NULL){
          |      free(store->path);
          |      store->path = NULL;
          |    }
          |    free(store);
          |  }
          |}
          END
          Utils.remove_margin(str)
        end

        def init_definition
          str =<<-END
          |/*
          |* Opens the store on the +path+.
          |*/
          |void _init(char * path, unsigned int page_count, unsigned int element_size,
          |           unsigned int unit_size, unsigned long element_count){
          |  store_struct * store;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |  store->path = malloc(strlen(path)+1);
          |  strcpy(store->path,path);
          |  store->page_count = page_count;
          |  store->element_size = element_size;
          |  store->unit_size = unit_size;
          |  store->element_count = element_count;
          |}
          END
          Utils.remove_margin(str)
        end

        def allocate_definition
          str =<<-END
          |/*
          |* Replaces default allocate with function returning wrapper for the
          |* store struct.
          |*/
          |VALUE allocate(){
          |  store_struct * store;
          |  store = ALLOC(store_struct);
          |  store->data = NULL;
          |  store->file = -1;
          |  store->empty_data = calloc(page_size(),1);
          |  store->path = NULL;
          |  store->page_count = 0;
          |  store->element_count = 0;
          |  store->element_size = 0;
          |  // db_mark == NULL - no internal elements have to be marked
          |  return Data_Wrap_Struct(self,NULL,free_store,store);
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
          |  store_struct * store;
          |  unsigned long allocated_elements_count;
          |  unsigned long elements_left;
          |
          |  Data_Get_Struct(self,store_struct,store);
          |  elements_left = count;
          |  while((elements_left + store->element_count) *
          |       store->element_size * store->unit_size >=
          |       store->page_count * page_size()){
          |    unmap_data(store);
          |    grow_file(self);
          |    map_data(self);
          |    allocated_elements_count = (store->page_count * page_size()) /
          |                                 (store->element_size * store->unit_size) -
          |                               ((store->page_count-1) * page_size()) /
          |                                 (store->element_size * store->unit_size);
          |
          |    if(elements_left >= allocated_elements_count){
          |      store->element_count += allocated_elements_count;
          |      elements_left -= allocated_elements_count;
          |    } else {
          |      break;
          |    }
          |  }
          |  store->element_count += elements_left;
          |}
          END
          Utils.remove_margin(str)
        end
      end

      protected
      # Checks the state of the store for write operation.
      # Throws an exception if the store is in invalid state.
      def check_write_state
        raise DatabaseError.new("Database is closed.") unless opened?
        raise DatabaseError.new("Database is readonly.") if readonly?
      end

      # Checks the state of the store for read operation.
      # Throws an exception if the store is in invalid state.
      def check_read_state
        raise DatabaseError.new("Database is closed.") unless opened?
      end
    end
  end
end
