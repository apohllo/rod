# encoding: utf-8
require 'rod/native/store'

module Rod
  module Native
    # This class is reponsible for writing and reading data
    # consisting of unstructured byte sequences from/to the storage device.
    class SequenceStore < Store
      # Initialize this store with given +path+
      # and +element_count+ (an element is one char).
      #
      # The store consists of a sequence of bytes.
      #
      # The +readonly+ option indicates if the store
      # is opened in readonly state (true by default).
      def initialize(path,element_count,readonly=true)
        unless Fixnum === element_count
          raise InvalidArgument.new(element_count,"element_count")
        end
        if element_count < 0
          raise InvalidArgument.new(element_count,"element_count")
        end
        page_count = super(path,readonly)
        _init(path,page_count,1,1,element_count)
      end

      # Write +bytes+ in the store at +offset+.
      def write_bytes(offset,bytes)
        raise InvalidArgument.new(bytes,"bytes") unless String === bytes
        check_offset_and_length(offset,bytes.bytesize)
        _write_bytes(offset,bytes)
      end

      # Read +length+ bytes from the store at +offset+.
      def read_bytes(offset,length)
        check_offset_and_length(offset,length)
        raise InvalidArgument.new(length,"length") unless Integer === length
        _read_bytes(offset,length)
      end

      class << self
        # The definition of the store struct.
        def struct
          str =<<-END
          |typedef struct store_struct_struct {
          |  char *         data;
          |  char *         empty_data;
          |  int            file;
          |  size_t         page_count;
          |  size_t         element_size;
          |  size_t         unit_size;
          |  unsigned long  element_count;
          |  char *         path;
          |} store_struct;
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
        builder.prefix(store_error)
        builder.prefix(open_file_definition)
        builder.prefix(close_file_definition)
        builder.prefix(allocated_pages_definition)
        builder.prefix(page_size_definition)
        builder.prefix(map_data_definition)
        builder.prefix(unmap_data_definition)
        builder.prefix(grow_file_definition)
        builder.prefix(free_store_definition)

        builder.c_singleton(allocate_definition)

        builder.c(page_size_reader_definition)
        builder.c(init_definition)
        builder.c(open_definition)
        builder.c(close_definition)
        builder.c(path_definition)
        builder.c(element_count_definition)
        builder.c(element_count_equals_definition)
        builder.c(page_count_definition)
        builder.c(page_count_equals_definition)
        builder.c(allocate_elements_definition)

        str =<<-END
        |/*
        |* Store a byte sequence in the store.
        |*/
        |void _write_bytes(unsigned long offset, VALUE bytes){
        |  unsigned long length;
        |  char * value;
        |  char * destination;
        |  store_struct * store;
        |
        |  Data_Get_Struct(self,store_struct,store);
        |  length = RSTRING_LEN(bytes);
        |  value = RSTRING_PTR(bytes);
        |
        |  destination = store->data + offset;
        |  memcpy(destination,value,length);
        |}
        END
        builder.c(Utils.remove_margin(str))

        str =<<-END
        |/*
        |* Read a byte sequence from the store.
        |*/
        |VALUE _read_bytes(unsigned long offset, unsgined long length){
        |  char * value;
        |  store_struct * store;
        |
        |  Data_Get_Struct(self,store_struct,store);
        |
        |  value = store->data + offset;
        |  return rb_str_new(value,length);
        |}
        END
        builder.c(Utils.remove_margin(str))
      end

      protected
      # Checks if the +offset+ and +length+ are valid.
      # Throws invalid argument exception if at least one of them is invalid.
      def check_offset_and_length(offset,length)
        if offset > _element_count || offset < 0
          raise IndexError.new("Byte offset: #{offset} out of scope: #{_element_count}")
        end
        if offset + length > _element_count || length < 0
          raise IndexError.new("Length: #{length} with offset #{offset} out of scope: #{_element_count}")
        end
      end
    end
  end
end
