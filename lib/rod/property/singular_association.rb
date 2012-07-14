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

      # Converts the association to fields in a C struct.
      def to_c_struct
        result = "  #{c_type(:ulong)} #{@name};\n"
        if polymorphic?
          result += "  #{c_type(:ulong)} #{@name}__class;\n"
        end
        result
      end

      # Defines the accessor of the association's constituents
      # (C struct field/fields that hold the association data).
      def define_c_accessors(builder)
        field_reader(@name,@klass.struct_name,c_type(:ulong),builder)
        field_writer(@name,@klass.struct_name,c_type(:ulong),builder)
        if polymorphic?
          field_reader("#{@name}__class",@klass.struct_name,c_type(:ulong),builder)
          field_writer("#{@name}__class",@klass.struct_name,c_type(:ulong),builder)
        end
      end

      # Make the C accessors private.
      def seal_c_accessors
        @klass.send(:private,"_#{@name}")
        @klass.send(:private,"_#{@name}=")
      end

      # Defines the getter of the Ruby class which corresponds to this association.
      def define_getter
        # optimization
        name = @name.to_s
        property = self
        class_name =
          if @options[:class_name]
            @options[:class_name]
          else
            "#{@klass.scope_name}::#{name.camelcase}"
          end
        klass = options[:polymorphic] ? nil : class_name.constantize
        @klass.send(:define_method,name) do
          value = instance_variable_get("@#{name}")
          if value.nil?
            return nil if self.new?
            rod_id = send("_#{name}",@rod_id)
            # the indices are shifted by 1, to leave 0 for nil
            if rod_id == 0
              value = nil
            else
              if property.polymorphic?
                klass = class_space.get(send("_#{name}__class",@rod_id))
              end
              value = klass.find_by_rod_id(rod_id)
            end
            # avoid change tracking
            instance_variable_set("@#{name}",value)
          end
          value
        end
      end

      # Defines the settor of the Ruby class which corresponds to this association.
      def define_setter
        # optimization
        name = @name.to_s
        @klass.send(:define_method,"#{name}=") do |value|
          old_value = send(name)
          send("#{name}_will_change!") unless old_value == value
          instance_variable_set("@#{name}", value)
          value
        end
      end

      # Returns the memory layout of the C struct fields that
      # correspond to this association.
      def layout
        unless polymorphic?
          "#{@name}[value:#{sizeof(:ulong)}]"
        else
          "#{@name}[value:#{sizeof(:ulong)}+" +
            "class:#{sizeof(:ulong)}]"
        end
      end

      # Update the DB information for the +subject+ about the +object+ which
      # is referenced via this singular association.
      # If the object is not yet stored, a reference updater
      # is registered to update the DB when it is stored.
      def update(subject,object)
        if object.nil?
          object_rod_id = 0
        else
          if object.new?
            # There is a referenced object, but its rod_id is not set.
            object.reference_updaters << Model::ReferenceUpdater.
              for_singular(subject,self,subject.database)
            return
          else
            object_rod_id = object.rod_id
          end
          # clear references, allowing for garbage collection
          # WARNING: don't use writer, since we don't want this change to be tracked
          #object.instance_variable_set("@#{name}",nil)
        end
        subject.__send__("_#{self.name}=", subject.rod_id, object_rod_id)
        if self.polymorphic?
          class_id = object.nil? ? 0 : object.class.name_hash
          subject.__send__("_#{self.name}__class=", subject.rod_id, class_id)
        end
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
