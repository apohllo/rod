module Rod
  module Index
    class Updater
      # Initializes the updater with the +property+ that is tracked by the
      # updater and the +index+, which is associated with that property.
      def initialize(property,index)
        raise InvalidArgument.new(nil,"property") if property.nil?
        raise InvalidArgument.new(nil,"index") if index.nil?
        @property = property
        @index = index
      end

      protected
      def remove_old_entry(object)
        unless object.new?
          @index[object.old_value(@property)].delete(object)
        end
      end

      def add_new_entry(object)
        @index[object.new_value(@property)] << object
      end
    end
  end
end
