require_relative 'base'

module Rod
  module Accessor
    # The accessor is used to load and save integer values of a particular
    # property from and to the database.
    class IntegerAccessor < Base
      # Save the value of the property of the +object+ to the database.
      def save(object)
        raise InvalidArgument.new(nil,"object") if object.nil?
        value = read_property(object)
        raise InvalidArgument.new(nil,@property.name) if value.nil?
        @database.write_integer(object_offset(object),@offset,value)
      end

      # Load the value of the property of the +object+ from the +database+.
      def load(object)
        raise InvalidArgument.new(nil,"object") if object.nil?
        write_property(object,@database.read_integer(object_offset(object),@offset))
      end
    end
  end
end
