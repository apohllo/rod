require 'rod/exception'
require 'rod/constants'
require 'rod/utils'

module Rod
  module Property
    # This class defines the properties which are used in Rod::Model::Resource.
    # These might be:
    # * fields
    # * has_one associations
    # * has_many associations
    # It provides basic data concerning these properties, such as name,
    # options, etc.
    class Base
      include Utils

      # The name of the property.
      attr_reader :name

      # The options of the property.
      attr_reader :options

      # Initializes the property associated with +klass+
      # with its +name+ and +options+.
      def initialize(klass,name,options)
        check_class(klass)
        @klass = klass
        check_name(name)
        @name = name
        check_options(options)
        @options = options.dup.freeze
      end

      def to_s
        "#{self.class.name.split("::").last} #{@name}:#{@ptions}@#{@klass}"
      end

      # Checks the difference in options between this and the +other+
      # property. The prefix of legacy module is removed from the
      # values of the options.
      def difference(other)
        self_options = {}
        self.options.each{|k,v| self_options[k] = v.to_s.sub(LEGACY_RE,"")}
        other_options = {}
        other.options.each{|k,v| other_options[k] = v.to_s.sub(LEGACY_RE,"")}
        differences = {}
        self_options.each do |option,value|
          if other_options[option] != value
            differences[option] = [value,other_options[option]]
          end
        end
        other_options.each do |option,value|
          if self_options[option] != value && !differences.has_key?(option)
            differences[option] = [self_options[option],value]
          end
        end
        differences
      end

      # Returns the index associated with the property.
      def index
        @index ||= Index::Base.create(path(@klass.database.path),@klass,@options)
      end

      # Returns true if the property has an index.
      def has_index?
        !!@options[:index]
      end

      # Get rid of the index that is associated with this property.
      def reset_index
        @index = nil
      end

      # Creates a copy of the property with a new +klass+.
      def copy(klass)
        self.class.new(klass,@name,@options)
      end

      # Defines finders (+find_by+ and +find_all_by+) for indexed property.
      def define_finders
        return unless has_index?
        # optimization
        name = @name.to_s
        property = self
        (class << @klass; self; end).class_eval do
          # Find all objects with given +value+ of the +property+.
          define_method("find_all_by_#{name}") do |value|
            property.index[value]
          end

          # Find first object with given +value+ of the +property+.
          define_method("find_by_#{name}") do |value|
            property.index[value][0]
          end
        end
      end

      # Returns the size of the property in basic units (byte octets).
      # The size is the number of byte-octets that are require to store
      # the information from the property or at least its meta-data (e.g. offset
      # and length in case of strings).
      def size
        raise RodException.new("Implement #{__method__} for #{self.class}")
      end

      # Returns the accessor object used to access the property values in the
      # given +database+ with the given +offset+.
      def accessor(database,offset)
        raise RodException.new("Implement #{__method__} for #{self.class}")
      end

      # Returns the updater object used to update an index if the property
      # changes.
      def updater(database,offset)
        raise RodException.new("Implement #{__method__} for #{self.class}")
      end

      # Returns the name of the method (i.e. symbol) that is used to read the
      # property.
      def reader
        @reader ||= self.name.to_sym
      end

      # Returns the name of the method (i.e. symbol) that is used to write the
      # property.
      def writer
        @writer ||= "#{self.name}=".to_sym
      end

      # Detailed string representation of the property.
      def inspect
        "#{self.class}<#{@klass}:#{self.name}:#{@options}>"
      end

      protected
      # Checks if the property +name+ is valid.
      def check_name(name)
        if !name.is_a?(Symbol) || name.to_s.empty? || INVALID_NAMES.has_key?(name)
          raise InvalidArgument.new(name,"property name")
        end
      end

      # Checks if the +klass+ is valid class for the property.
      def check_class(klass)
        raise InvalidArgument.new(klass,"class") if klass.nil?
      end
    end
  end
end
