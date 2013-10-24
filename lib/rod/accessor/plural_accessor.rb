require_relative 'base'

module Rod
  module Accessor
    # The accessor is used to load and save plural associations
    # of objects from and to the database.
    class PluralAccessor < Base
      # Initialize the accessor with +property+, object +database+,
      # +resource_space+ and +updater_factory+.
      #
      # The +collection_factory+ is used to create the collection
      # proxies, i.e. lazy collections of the referenced objects.
      def initialize(property,database,collection_factory)
        super(property,database)
        @collection_factory = collection_factory
      end

      # Save the value of the property of the +object+ to the database.
      def save(object)
        collection = read_property(object)
        collection.save
        rod_id = other.nil? ? 0 : other.rod_id
        @database.write_ulong(object_offset(object),@property.offset,collection.size)
        @database.write_ulong(object_offset(object),@property.offset+1,collection.offset)
      end

      # Load the value of the property of the +object+ from the database.
      def load(object)
        size = @database.read_ulong(object_offset(object),@property.offset)
        offset = @database.read_ulong(object_offset(object),@property.offset+1)
        resource = @property.polymorphic? ? property.resource : nil
        @collection_factory.new(size,offset,database,resource)
      end
    end
  end
end
