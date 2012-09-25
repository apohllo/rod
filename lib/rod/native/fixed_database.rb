# encoding: utf-8
require 'rod/native/base'

module Rod
  module Native
    # This class is reponsible for writing and reading fixed structures
    # consising of basic values (int, ulong, float) from/to the storage device.
    class FixedDatabase < Base
      # The mapping of storage function names to the C types.
      TYPES = {"integer" => "int", "float" => "double", "ulong" => "unsigned long"}

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
        unless Fixnum === element_size
          raise InvalidArgument.new(element_size,"element_size")
        end
        if element_size < 0
          raise InvalidArgument.new(element_size,"element_size")
        end
        unless Fixnum === element_count
          raise InvalidArgument.new(element_count,"element_count")
        end
        if element_count < 0
          raise InvalidArgument.new(element_count,"element_count")
        end
        page_count = super(path,readonly)
        _init(path,page_count,element_size,8,element_count)
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

      class << self
        # The definition of the database struct.
        def struct
          str =<<-END
          |typedef struct flexible_database_struct {
          |  uint64_t *     data;
          |  char *         empty_data;
          |  int            file;
          |  size_t         page_count;
          |  size_t         element_size;
          |  size_t         unit_size;
          |  unsigned long  element_count;
          |  char *         path;
          |} database_struct;
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
        builder.prefix(open_file_definition)
        builder.prefix(close_file_definition)
        builder.prefix(allocated_pages_definition)
        builder.prefix(page_size_definition)
        builder.prefix(map_data_definition)
        builder.prefix(unmap_data_definition)
        builder.prefix(grow_file_definition)
        builder.prefix(free_database_definition)

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

        str =<<-END
        |/*
        |* Returns the size of elements in the database.
        |*/
        |unsigned long _element_size(){
        |  database_struct * database;
        |
        |  Data_Get_Struct(self,database_struct,database);
        |  return database->element_size;
        |}
        END
        builder.c(Utils.remove_margin(str))

        builder.c(Utils.remove_margin(str))

        TYPES.each do |name,cname|
          str =<<-END
          |/*
          |* Save a(n) #{name} to the database.
          |*/
          |void _save_#{name}(unsigned long element_offset,unsigned long property_offset,
          |       #{cname} value){
          |  union data_union {
          |    uint64_t as_uint;
          |    #{cname} as_value;
          |  };
          |  database_struct * database;
          |  uint64_t as_uint;
          |  union data_union data;
          |
          |  data.as_uint = 0;
          |  data.as_value = value;
          |
          |#ifdef __BYTE_ORDER
          |#  if __BYTE_ORDER == __BIG_ENDIAN
          |  // TODO #220 #221
          |  data.as_uint = bswap_64(data.as_uint);
          |#  endif
          |#endif
          |
          |  Data_Get_Struct(self,database_struct,database);
          |  database->data[element_offset*database->element_size+property_offset] =
          |    data.as_uint;
          |}
          END
          builder.c(Utils.remove_margin(str))

          str =<<-END
          |/*
          |* Read a(n) #{name} from the database.
          |*/
          |#{cname} _read_#{name}(unsigned long element_offset,
          |                       unsigned long property_offset){
          |  union data_union {
          |    uint64_t as_uint;
          |    #{cname} as_value;
          |  };
          |  database_struct * database;
          |  uint64_t as_uint;
          |  union data_union data;
          |
          |  Data_Get_Struct(self,database_struct,database);
          |
          |  data.as_uint = database->data[element_offset*database->element_size+property_offset];
          |#ifdef __BYTE_ORDER
          |#  if __BYTE_ORDER == __BIG_ENDIAN
          |  // TODO #220 #221
          |  data.as_uint = bswap_64(data.as_uint);
          |#  endif
          |#endif
          |  return data.as_value;
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
    end
  end
end
