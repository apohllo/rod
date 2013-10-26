require 'rod/property/base'

module Rod
  module Property
    # This class defines the +has_many+ (plural association) property.
    # A +has_many+ property has to define its +name+.
    class PluralAssociation < Base
      # Creates new plural association associated with +klass+
      # with given +name+ and +options+.
      def initialize(klass,name,options={})
        super(klass,name,options)
      end

      # Predicate indicating that this property is a field.
      def field?
        false
      end

      # Predicate indicating that this property is an association.
      def association?
        true
      end

      # Predicate indicating that this property is not a singular association.
      def singular?
        false
      end

      # Predicate indicating that this property is a plural association.
      def plural?
        true
      end

      # Predicate indicating that this property is polymorphic.
      def polymorphic?
        @options[:polymorphic]
      end

      # Returns the metadata of the association in form of a hash.
      def to_hash
        @options.dup
      end

      # The size of the plural association data in byte-octets.
      def size
        2
      end

      # The accessor of the plural association associated with the given
      # +database+.
      def accessor(database,offset)
        Accessor::PluralAccessor.new(self,database.structures,offset)
      end

      protected
      # Check if the property has valid options.
      # An exceptions is raised if they are not.
      def check_options(options)
        #TODO implement
      end
    end
  end
end
