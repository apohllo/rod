module Rod
  module Property
    module ClassMethods
      # The mapping between macro functions and property accessors.
      ACCESSOR_MAPPING = {
        :field => :fields,
        :has_one => :singular_associations,
        :has_many => :plural_associations
      }

      # A macro-style function used to indicate that given piece of data
      # is stored in the database. See Rod::Property::Field for valid
      # types and options.
      #
      # Warning!
      # 1) :rod_id is a predefined field
      # 2) all C keywords are not valid field names
      def field(name, type, options={})
        if self.property(name)
          raise InvalidArgument.new(name,"doubled property name")
        end
        self.fields << Property::Field.new(self,name,type,options)
        # clear cached properties
        @properties = nil
      end

      # A macro-style function used to indicate that instances of this
      # class are associated with many instances of some other class. The
      # name of the class is guessed from the property name, but you can
      # change it via options.
      # Options:
      # * +:class_name+ - the name of the class (as String) associated
      #   with this class
      # * +:polymorphic+ - if set to +true+ the association is polymorphic (allows to acess
      #   objects of different classes via this association)
      def has_many(name, options={})
        if self.property(name)
          raise InvalidArgument.new(name,"doubled property name")
        end
        self.plural_associations << Property::PluralAssociation.new(self,name,options)
        # clear cached properties
        @properties = nil
      end

      # A macro-style function used to indicate that instances of this
      # class are associated with one instance of some other class. The
      # name of the class is guessed from the property name, but you can
      # change it via options. See Rod::Property::SingularAssociation for details.
      def has_one(name, options={})
        if self.property(name)
          raise InvalidArgument.new(name,"doubled property name")
        end
        self.singular_associations <<
          Property::SingularAssociation.new(self,name,options)
        # clear cached properties
        @properties = nil
      end

      # Returns the fields of this class.
      def fields
        @fields ||= superclass.fields.map{|p| p.copy(self)}
      rescue NoMethodError
        @fields = [Property::Field.new(self,:rod_id,:ulong)]
      end

      # Returns singular associations of this class.
      def singular_associations
        @singular_associations ||= superclass.
          singular_associations.map{|p| p.copy(self)}
      rescue NoMethodError
        @singular_associations = []
      end

      # Returns plural associations of this class.
      def plural_associations
        @plural_associations ||= superclass.
          plural_associations.map{|p| p.copy(self)}
      rescue NoMethodError
        @plural_associations = []
      end

      # Fields, singular and plural associations.
      def properties
        @properties ||= self.fields + self.singular_associations + self.plural_associations
      end

      # Returns the property with given +name+ or nil if it doesn't exist.
      def property(name)
        properties.find{|p| p.name == name}
      end

      # Returns (and caches) only properties which are indexed.
      def indexed_properties
        @indexed_properties ||= self.properties.select{|p| p.options[:index]}
      end
    end
  end
end
