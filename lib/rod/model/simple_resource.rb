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

      # Cache for the resources. If +cache_factory+
      # is provided, it is used to create the cache.
      # By default this is +Cache+.
      def cache(cache_factory=Cache)
        @cache ||= cache_factory.new
      end

      # Returns the metadata for the simple resource.
      # If the +metadata_factory+ is provided, it is
      # used to create the metadata. By default this is
      # Metadata class.
      def metadata(metadata_factory=Metadata)
        @metadata ||= metadata_factory.new(self)
      end
    end
  end
end
