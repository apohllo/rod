require_relative 'base'

module Rod
  module Accessor
    # The accessor is used to load and save float values of a particular
    # property from and to the database.
    class FloatAccessor < Base
      # Save the value of the property of the +object+ to the database.
      def save(object)
        raise InvalidArgument.new("object",nil) if object.nil?
        @database.write_float(object_offset(object),
                              @property.offset,read_property(object))
      end

      # Load the value of the property of the +object+ from the +database+.
      def load(object)
        raise InvalidArgument.new("object",nil) if object.nil?
        write_property(object,@database.read_float(object_offset(object),
                                                   @property.offset))
      end
    end
  end
end
