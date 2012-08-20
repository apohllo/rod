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

      # Converts the association to fields in a C struct.
      def to_c_struct
        "  #{c_type(:ulong)} #{@name}_offset;\n" +
          "  #{c_type(:ulong)} #{@name}_count;\n"
      end

      # Defines the accessor of the association's constituents
      # (C struct field/fields that hold the association data).
      def define_c_accessors(builder)
        field_reader("#{@name}_count",@klass.struct_name,c_type(:ulong),builder)
        field_reader("#{@name}_offset",@klass.struct_name,c_type(:ulong),builder)
        field_writer("#{@name}_count",@klass.struct_name,c_type(:ulong),builder)
        field_writer("#{@name}_offset",@klass.struct_name,c_type(:ulong),builder)
      end

      # Make the C accessors private.
      def seal_c_accessors
        @klass.private "_#{@name}_count"
        @klass.private "_#{@name}_count="
        @klass.private "_#{@name}_offset"
        @klass.private "_#{@name}_offset="
      end

      # Make the C accessors private.
      def seal_c_accessors
        @klass.send(:private,"_#{@name}_count")
        @klass.send(:private,"_#{@name}_count=")
        @klass.send(:private,"_#{@name}_offset")
        @klass.send(:private,"_#{@name}_offset=")
      end

      # Defines the getter of the Ruby class which corresponds to this association.
      def define_getter
        # optimization
        name = @name.to_s
        class_name =
          if options[:class_name]
            options[:class_name]
          else
            # +parent_name+ is defined in ActiveSupport core extensions.
            "#{@klass.parent_name}::#{::English::Inflect.singular(name).camelcase}"
          end
        klass = options[:polymorphic] ? nil : class_name.constantize
        database = @klass.database
        @klass.send(:define_method,"#{name}") do
          proxy = instance_variable_get("@#{name}")
          if proxy.nil?
            if self.new?
              count = 0
              offset = 0
            else
              count = self.send("_#{name}_count",@rod_id)
              offset = self.send("_#{name}_offset",@rod_id)
            end
            proxy = CollectionProxy.new(count,database,offset,klass)
            instance_variable_set("@#{name}", proxy)
          end
          proxy
        end
        # count getter
        @klass.send(:define_method,"#{name}_count") do
          if (instance_variable_get("@#{name}") != nil)
            return instance_variable_get("@#{name}").count
          else
            if self.new?
              return 0
            else
              return send("_#{name}_count",@rod_id)
            end
          end
        end
      end

      # Defines the settor of the Ruby class which corresponds to this association.
      def define_setter
        # optimization
        name = @name.to_s
        @klass.send(:define_method,"#{name}=") do |value|
          proxy = send(name)
          proxy.clear
          value.each do |object|
            proxy << object
          end
          proxy
        end
      end

      # Returns the memory layout of the C struct fields that
      # correspond to this association.
      def layout
        "#{@name}[offset:#{sizeof(:ulong)}+" +
          "count:#{sizeof(:ulong)}]"
      end

      # Updates in the DB the +count+ and +offset+ of elements for the +subject+.
      def update(subject,count,offset)
        subject.__send__("_#{self.name}_count=",subject.rod_id,count)
        subject.__send__("_#{self.name}_offset=",subject.rod_id,offset)
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
