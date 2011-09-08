module Rod
  # A base class for all classes stored in the DataBase
  # (both user defined and DB defined).
  class AbstractModel
    # Empty string.
    def self.typedef_struct
      raise RodException.new("#typdef_struct called for AbstractModel")
    end

    # C-struct name of the model.
    def self.struct_name
      raise RodException.new("#typdef_struct called for AbstractModel")
    end

    # Path to the file storing the model data.
    def self.path_for_data(path)
      "#{path}#{self.struct_name}.dat"
    end

    # Default implementation prints nothing.
    def self.layout
    end

    # By default there are no fields.
    def self.fields
      []
    end

    # By default nothing is built.
    def self.build_structure
    end

    # Default cache for models.
    def self.cache
      @cache ||= Cache.new
    end

    # There are no indexed properties.
    def self.indexed_properties
      []
    end

    # By default properties are empty.
    def self.properties
      []
    end

    # Returns meta-data (in the form of a hash) for the model.
    def self.metadata
      meta = {}
      meta[:superclass] = self.superclass.name
      meta
    end

    # Checks if the +metadata+ are compatible with the class definition.
    def self.compatible?(metadata)
      self.difference(metadata).empty?
    end

    # Calculates the difference between the classes metadata
    # and the +metadata+ provided.
    def self.difference(metadata)
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
              result << [meta1,meta2]
            end
          end
        else
          if other_metadata[type] != values
            result << [values,other_metadata[type]]
          end
        end
      end
      result
    end

  end
end
