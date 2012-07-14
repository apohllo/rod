require 'rod/property/base'
require 'rod/constants'
require 'json'

module Rod
  module Property
    # This class defines the field property.
    # A field has to define its +name+ and its +type+.
    class Field < Base
      # The type of the property.
      attr_reader :type

      # The valid types of fields.
      VALID_TYPES = [:string, :integer, :float, :ulong, :object, :json]

      # The fields with variable size.
      VARIABLE_TYPES = [:string, :object, :json]

      # The name of the field used to identify the objects.
      IDENTIFIER = :rod_id

      # Initialize the field associated with the +klass+ with +name+, +type+ and +options+.
      # The type should be one of:
      # * +:integer+
      # * +:ulong+
      # * +:float+
      # * +:string+
      # * +:object+ (value is marshaled durign storage, and unmarshaled during read)
      # * +:json+ (value is dumped in JSON format during storage, and loaded during read.
      #   Note: some Ruby types are not unified during conversion, e.g. String and Symbol)
      # The valid options are:
      # * +:index+ builds an index for the field and might be:
      # ** +:flat+ simple hash index (+true+ works as well for backwards compatiblity)
      # ** +:segmented+ index split for 1001 pieces for shorter load times (only
      #   one piece is loaded on one look-up)
      def initialize(klass,name,type,options={})
        super(klass,name,options)
        check_type(type)
        @type = type
      end

      def to_s
        "Field #{@name}:#{@type}:#{@ptions}@#{@klass}"
      end

      # Creates a copy of the field with a new +klass+.
      def copy(klass)
        self.class.new(klass,@name,@type,@options)
      end

      # Predicate indicating that this property is a field.
      def field?
        true
      end

      # Predicate indicating that this property is not an association.
      def association?
        false
      end

      # Returns the default value for given type of field.
      def default_value
        case @type
        when :integer
          0
        when :ulong
          0
        when :float
          0.0
        when :string
          ''
        when :object, :json
          nil
        end
      end

      # Returns true if the field has a variable size.
      def variable_size?
        VARIABLE_TYPES.include?(@type)
      end

      # Dumps the +value+ of the field according to its type.
      def dump(value)
        case @type
        when :object
          Marshal.dump(value)
        when :json
          JSON.dump([value])
        when :string
          # TODO the encoding should be stored in the DB
          # or configured globally
          value.encode("utf-8")
        when :ulong
          raise InvalidArgument.new(value,"ulong") if value < 0
          value
        else
          value
        end
      end

      # Loads the +value+ of the field according to its type.
      def load(value)
        return value unless variable_size?
        case @type
        when :object
          value.force_encoding("ascii-8bit")
          value = Marshal.load(value) rescue nil
        when :json
          value.force_encoding("ascii-8bit")
          value = JSON.load(value).first rescue nil
        when :string
          value.force_encoding("utf-8")
        end
        value
      end

      # Returns true if the field is used to identify the objects.
      def identifier?
        @name == IDENTIFIER
      end

      # Returns the metadata of the field in form of a hash.
      def to_hash
        if self.identifier?
          {}
        else
          @options.merge({:type => @type})
        end
      end

      # Converts the field to fields in a C struct.
      def to_c_struct
        unless variable_size?
          str = <<-SUBEND
          |#ifdef __BYTE_ORDER
          |#  if __BYTE_ORDER == __BIG_ENDIAN
          |  uint64_t #{@name};
          |#  else
          |  #{c_type(@type)} #{@name};
          |#  endif
          |#else
          |  #{c_type(@type)} #{@name};
          |#endif
          SUBEND
          Utils.remove_margin(str)
        else
          "  #{c_type(:ulong)} #{@name}_length;\n" +
            "  #{c_type(:ulong)} #{@name}_offset;\n"
        end
      end

      # Defines the accessor of the field's constituents
      # (C struct field/fields that hold the field data).
      def define_c_accessors(builder)
        unless variable_size?
          field_reader(@name,@klass.struct_name,c_type(@type),builder)
          field_writer(@name,@klass.struct_name,c_type(@type),builder)
        else
          field_reader("#{@name}_length",@klass.struct_name,c_type(:ulong),builder)
          field_reader("#{@name}_offset",@klass.struct_name,c_type(:ulong),builder)
          field_writer("#{@name}_length",@klass.struct_name,c_type(:ulong),builder)
          field_writer("#{@name}_offset",@klass.struct_name,c_type(:ulong),builder)
        end
      end

      # Make the C accessors private.
      def seal_c_accessors
        unless variable_size?
          @klass.send(:private,"_#{@name}")
          @klass.send(:private,"_#{@name}=")
        else
          @klass.send(:private,"_#{@name}_length")
          @klass.send(:private,"_#{@name}_length=")
          @klass.send(:private,"_#{@name}_offset")
          @klass.send(:private,"_#{@name}_offset=")
        end
      end

      # Defines the getter of the Ruby class which corresponds to this field.
      def define_getter
        field = @name.to_s
        unless variable_size?
          @klass.send(:define_method,field) do
            value = instance_variable_get("@#{field}")
            if value.nil?
              if self.new?
                value = nil
              else
                value = send("_#{field}",@rod_id)
              end
              instance_variable_set("@#{field}",value)
            end
            value
          end
        else
          is_object = @type != :string
          type = @type
          property = self
          database = @klass.database
          @klass.send(:define_method,field) do
            value = instance_variable_get("@#{field}")
            if value.nil? # first call
              if self.new?
                return (is_object ? nil : "")
              else
                length = send("_#{field}_length", @rod_id)
                if length == 0
                  return (is_object ? nil : "")
                end
                offset = send("_#{field}_offset", @rod_id)
                read_options = {}
                if is_object
                  read_options[:skip_encoding] = true
                end
                value = database.read_string(length, offset)
                value = property.load(value)
                # caching Ruby representation
                # don't use setter - avoid change tracking
                instance_variable_set("@#{field}",value)
              end
            end
            value
          end
        end
      end

      # Defines the settor of the Ruby class which corresponds to this field.
      def define_setter
        # optimization
        field = @name.to_s
        @klass.send(:define_method,"#{field}=") do |value|
          old_value = send(field)
          send("#{field}_will_change!") unless old_value == value
          instance_variable_set("@#{field}",value)
          value
        end
      end

      # Returns the memory layout of the C struct fields that
      # correspond to this field.
      def layout
        unless variable_size?
          "#{@name}[value:#{sizeof(@type)}]"
        else
          "#{@name}[length:#{sizeof(:ulong)}+" +
            "offset:#{sizeof(:ulong)}]"
        end
      end

      # Updates in the DB this field to the actual value of the +subject+.
      def update(subject)
        if self.variable_size?
          value = self.dump(subject.__send__(self.name))
          length, offset = subject.database.set_string(value)
          subject.__send__("_#{self.name}_length=",subject.rod_id,length)
          subject.__send__("_#{self.name}_offset=",subject.rod_id,offset)
        else
          subject.__send__("_#{self.name}=",subject.rod_id,subject.__send__(self.name))
        end
      end

      protected
      # Check if the property has a valid type.
      # An exceptions is raised if the type is invalid.
      def check_type(type)
        unless VALID_TYPES.include?(type)
          raise InvalidArgument.new(type,"field type")
        end
      end

      # Check if the property has valid options.
      # An exceptions is raised if they are not.
      def check_options(options)
        #TODO implement
      end
    end
  end
end
