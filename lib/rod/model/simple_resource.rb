# encoding: utf-8

module Rod
  module Model
    # A base module for all classes stored in the Database
    # (both user defined and DB defined).
    module SimpleResource
      # Path to the file storing the model data.
      def path_for_data(path)
        "#{path}#{self.struct_name}.dat"
      end

      # Default implementation prints nothing.
      def layout
      end

      # By default nothing is built.
      def build_structure
      end

      # Default cache for models.
      def cache
        @cache ||= Model::Cache.new
      end

      # Returns meta-data (in the form of a hash) for the model.
      def metadata
        meta = {}
        meta[:superclass] = self.superclass.name
        meta
      end

      # Checks if the +metadata+ are compatible with the class definition.
      def compatible?(metadata)
        self.difference(metadata).empty?
      end

      # Calculates the difference between the classes metadata
      # and the +metadata+ provided.
      def difference(metadata)
        my_metadata = self.metadata
        other_metadata = metadata.dup
        other_metadata.delete(:count)
        result = []
        my_metadata.each do |type,values|
          # TODO #161 the order of properties should be preserved for the
          # whole class, not only for each type of properties.
          if [:fields,:has_one,:has_many].include?(type)
            values.to_a.zip(other_metadata[type].to_a) do |meta1,meta2|
              if meta1 != meta2
                result << [meta2,meta1]
              end
            end
          else
            if other_metadata[type] != values
              result << [other_metadata[type],values]
            end
          end
        end
        result
      end
    end
  end
end
