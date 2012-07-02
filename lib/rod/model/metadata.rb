module Rod
  module Model
    module Metadata
      # Metadata for the model class.
      def metadata
        meta = super
        {:fields => :fields,
         :has_one => :singular_associations,
         :has_many => :plural_associations}.each do |type,method|
          # fields
          metadata = {}
          self.send(method).each do |property|
            next if property.field? && property.identifier?
            metadata[property.name] = property.metadata
          end
          unless metadata.empty?
            meta[type] = metadata
          end
        end
        meta
      end
    end
  end
end
