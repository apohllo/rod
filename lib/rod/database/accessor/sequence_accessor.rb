require_relative 'base'

module Rod
  module Database
    module Accessor
      # Base class for sequence accessors.
      class SequenceAccessor < Base
        ASCII_8BIT = "ascii-8bit".freeze
        UTF_8 = "utf-8".freeze

        # Initialize the accessor with +property+, object +database+ and
        # +bytes_database+.
        def initialize(property,database,bytes_database)
          super(property,database)
          @bytes_database = bytes_database
        end

        # Save the value of the property of the +object+ to the database.
        def save(object)
          raise InvalidArgument.new("object",nil) if object.nil?
          value = dump_value(read_property(object))
          # TODO #239 reuse space in bytes database
          offset = @bytes_database.element_count
          length = value.bytesize
          @bytes_database.allocate_elements(length)
          @bytes_database.write_bytes(offset,value)
          @database.write_ulong(object_offset(object),@property.offset,offset)
          @database.write_ulong(object_offset(object),@property.offset+1,length)
        end

        # Load the value of the property of the +object+ from the database.
        def load(object)
          raise InvalidArgument.new("object",nil) if object.nil?
          offset = @database.read_ulong(object_offset(object),@property.offset)
          length = @database.read_ulong(object_offset(object),@property.offset+1)
          value = load_value(@bytes_database.read_bytes(offset,length))
          # TODO #240 implement lazy value accessors
          write_property(object,value)
        end

      end
    end
  end
end
