module Rod
  module Model
    class ClassSpace
      # Initializes the class space with empty classes.
      # TODO consider special classes as always present in the class
      # space.
      def initialize
        @classes = {}
        @anonymous = []
      end

      # Returns the class for the given +klass_hash+.
      def get(klass_hash)
        update_anonymouns unless @anonymous.empty?
        klass = @classes[klass_hash]
        if klass.nil?
          raise RodException.new("There is no class with name hash '#{klass_hash}'!\n" +
                                "Check if all needed classes are loaded.")
        end
        klass
      end

      # Adds given +klass+ to the class space.
      def add(klass)
        begin
          @classes[klass.name_hash] = klass
        rescue AnonymousClass
          @anonymous << klass
        end
        klass.class_space = self
      end

      protected
      def update_anonymouns
        removed = []
        @anonymous.each do |resource|
          begin
            @classes[resource.name_hash] = resource
            removed << resource
          rescue AnonymousClass
            # no luck this time
          end
        end
        @anonymous -= removed
      end
    end
  end
end
