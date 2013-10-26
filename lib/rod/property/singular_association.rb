require 'rod/property/base'

module Rod
  module Property
    # This class defines the +has_one+ (singular association) property.
    # A +has_one+ property has to define its +name+.
    class SingularAssociation < Base
      # Creates new singular association associated with +klass+,
      # with given +name+ and +options+.
      # Valid options are:
      # * +:class_name+ - the name of the class (as String) associated
      #   with this class
      # * +:polymorphic+ - if set to +true+ the association is polymorphic (allows to access
      #   objects of different classes via this association).
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

      # Predicate indicating that this property is a singular association.
      def singular?
        true
      end

      # Predicate indicating that this property is not a plural association.
      def plural?
        false
      end

      # Predicate indicating that this property is polymorphic.
      def polymorphic?
        @options[:polymorphic]
      end

      # Returns the metadata of the association in form of a hash.
      def to_hash
        @options.dup
      end

      # The size of the singular association data in byte-octets.
      def size
        if polymorphic?
          2
        else
          1
        end
      end

      # The accessor of the singular association associated with the given
      # +database+.
      def accessor(database,offset)
        Accessor::SingularAccessor.new(self,database.structures,offset)
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
