module Rod
  module Model
    class ClassSpace
      # Initializes the class space with empty classes.
      # TODO consider special classes as always present in the class
      # space.
      def initialize
        @classes = {}
      end

      # Returns the class for the given +klass_hash+.
      def get(klass_hash)
        klass = @classes[klass_hash]
        if klass.nil?
          raise RodException.new("There is no class with name hash '#{klass_hash}'!\n" +
                                "Check if all needed classes are loaded.")
        end
        klass
      end

      # Adds given +klass+ to the class space.
      def add(klass)
        @classes[klass.name_hash] = klass
        klass.class_space = self
      end
    end
  end
end
