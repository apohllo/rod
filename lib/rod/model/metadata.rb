# encoding: utf-8

module Rod
  module Model
    # The metadata class provides metadata abstraction
    # for resources. The meta-data stores information
    # about various aspects of the class allowing for
    # checking if the runtime class definition is compatible
    # with the database class definition as well as for
    # re-generating the class in order to get the access to
    # the data, even if the class definition is not available.
    class Metadata
      # Initializes the metadata for a given +klass+.
      def initialize(klass)
        @data = {}
        @data[:name] = klass.name
        @data[:superclass] = klass.superclass.name
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

      # Iterates over the meta-data.
      def each(&block)
        @data.each(&block)
      end

      # Returns the metadata as string.
      def inspect
        @data.inspect
      end


      # Checks if the +other+ meta-data are compatible these meta-data.
      def compatible?(other)
        self.difference(other).empty?
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

      alias psych_to_yaml to_yaml
    end
  end
end
