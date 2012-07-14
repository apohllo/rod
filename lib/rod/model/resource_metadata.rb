# encoding: utf-8

module Rod
  module Model
    class ResourceMetadata < Metadata
      def initialize(klass)
        super
        Property::ClassMethods::ACCESSOR_MAPPING.each do |type,method|
          property_type_data = {}
          @klass.send(method).each do |property|
            next if property.to_hash.empty?
            property_type_data[property.name] = property.to_hash
          end
          unless property_type_data.empty?
            @data[type] = property_type_data
          end
        end
      end
    end
  end
end
