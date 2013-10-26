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

      # The size of the filed data in byte-octets.
      def size
        if variable_size?
          2
        else
          1
        end
      end

      # The accessor of the field associated with the given +container+.
      def accessor(container,offset)
        case self.type
        when :integer
          Accessor::IntegerAccessor.new(self,container.structures,offset)
        when :ulong
          Accessor::UlongAccessor.new(self,container.structures,offset)
        when :float
          Accessor::FloatAccessor.new(self,container.structures,offset)
        when :string
          Accessor::StringAccessor.new(self,container.structures,container.sequences,offset)
        when :json
          Accessor::JsonAccessor.new(self,container.structures,container.sequences,offset)
        when :object
          Accessor::ObjectAccessor.new(self,container.structures,container.sequences,offset)
        else
          raise RodException.new("Type #{self.type} doesn't have an implementation of the accessor yet.")
        end
      end

      # Returns the updater object used to update an index if the property
      # changes.
      def updater(index)
        Index::FieldUpdater.new(self,index)
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
