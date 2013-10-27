require 'singleton'

module Rod
  module Model
    class ResourceSpace
      include Singleton
      include NameConversion

      # Initializes the class space with empty classes.
      def initialize(name_converter: NameConversion)
        @classes = {}
        @anonymous = []
        @name_converter = name_converter
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

      # Adds given +resource+ to the class space.
      def add(resource)
        begin
          @classes[@name_converter.name_hash(resource)] = resource
        rescue AnonymousClass
          @anonymous << resource
        end
      end

      # Clears the object space.
      def clear
        @classes.clear
        @anonymous.clear
      end

      protected
      def update_anonymouns
        removed = []
        @anonymous.each do |resource|
          begin
            @classes[@name_converter.name_hash(klass)] = resource
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
