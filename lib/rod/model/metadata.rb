# encoding: utf-8

module Rod
  module Model
    # The metadata class provides metadata abstraction
    # for resources.
    class Metadata
      # The name of the superclass of the class the metadata is about.
      attr_reader :superclass_name

      # Initializes the metadata with a given +klass+.
      def initialize(klass)
        @klass = klass
        @superclass_name = klass.superclass.name
        @data = {}
        @data[:name] = @klass.name
        @data[:superclass] = @superclass_name
        @data[:count] = 0
      end

      # Retrieves given info from the metadata.
      def [](key)
        @data[key]
      end

      # Updates given info in the metadata.
      def []=(key,value)
        @data[key] = value
      end

      # Iterates over the data.
      def each(&block)
        @data.each(&block)
      end

      # Returns the metadata as string.
      def inspect
        @data.inspect
      end


      # Checks if the +metadata+ are compatible with the class definition.
      def compatible?(metadata)
        self.difference(metadata).empty?
      end

      # Calculates the difference between this metadata
      # and the +other+ metadata.
      def difference(other)
        result = []
        self.each do |type,values|
          next if type == :count
          if Property::ClassMethods::ACCESSOR_MAPPING.keys.include?(type)
            # properties
            values.to_a.zip(other[type].to_a) do |meta1,meta2|
              if meta1 != meta2
                result << [meta2,meta1]
              end
            end
          else
            # other stuff
            if other[type] != values
              result << [other[type],values]
            end
          end
        end
        result
      end

      # Converts the metadata to yaml.
      def to_yaml(*args)
        @data.to_yaml(*args)
      end
    end
  end
end
