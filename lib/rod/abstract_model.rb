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
    def self.metadata(database)
      meta = {}
      meta[:count] = database.count(self)
      meta[:superclass] = self.superclass.name
      meta
    end

    # Checks if the +metadata+ are compatible with the class definition.
    def self.compatible?(metadata,database)
      self_metadata = self.metadata(database)
      other_metadata = metadata.dup
      self_metadata.delete(:count)
      other_metadata.delete(:count)
      self_metadata == other_metadata
    end

  end
end
