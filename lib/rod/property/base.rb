require 'rod/exception'
require 'rod/constants'

module Rod
  module Property
    # This class defines the properties which are used in Rod::Model.
    # These might be:
    # * fields
    # * has_one associations
    # * has_many associations
    # It provides basic data concerning these properties, such as name,
    # options, etc.
    class Base
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
        @index ||= Index::Base.create(path(@klass.database.path),@klass,@options,@type)
      end

      # Returns true if the property has an index.
      def has_index?
        !@options[:index].nil?
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

      protected
      # The name of the file or directory (for given +relative_path+), where
      # the data of the property (e.g. index) is stored.
      def path(relative_path)
        "#{relative_path}#{@klass.model_path}_#{@name}"
      end

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

      # Reads the value of a field +name+ of the C struct +struct_name+
      # that corresponds to given Ruby object. The C +result_type+
      # of the result has to be specified.
      def field_reader(name,struct_name,result_type,builder)
        str =<<-END
        |#{result_type} _#{name}(unsigned long object_rod_id){
	|  VALUE klass;
	|  #{struct_name} * pointer;
        |#ifdef __BYTE_ORDER
        |#  if __BYTE_ORDER == __BIG_ENDIAN
        |  uint64_t as_uint;
        |  uint64_t result_swapped;
        |#  endif
        |#endif
        |
        |  if(object_rod_id == 0){
        |    rb_raise(rodException(), "Invalid object rod_id (0)");
        |  }
        |  klass = rb_funcall(self,rb_intern("class"),0);
        |  pointer = (#{struct_name} *)
        |    NUM2ULONG(rb_funcall(klass,rb_intern("rod_pointer"),0));
        |  if(pointer == 0){
        |    rb_raise(rodException(), "Invalid model pointer (0). DB is closed.");
        |  }
        |#ifdef __BYTE_ORDER
        |#  if __BYTE_ORDER == __BIG_ENDIAN
        |  // This code assumes that all values are 64 bit wide. This is not true
        |  // on 32-bit systems but is addressed in #221
        |  as_uint = (pointer + object_rod_id - 1)->#{name};
        |  result_swapped = bswap_64(*((uint64_t *)((char *)&as_uint)));
        |  return *(#{result_type} *)((char *)&result_swapped);
        |#  else
        |  return (pointer + object_rod_id - 1)->#{name};
        |#  endif
        |#else
        |  return (pointer + object_rod_id - 1)->#{name};
        |#endif
        |}
        END
        builder.c(str.margin)
      end

      # Writes the value of a field +name+ of the C struct +struct_name+
      # that corresponds to given Ruby object. The C +arg_type+
      # of the argument has to be specified.
      def field_writer(name,struct_name,arg_type,builder)
        str =<<-END
        |void _#{name}_equals(unsigned long object_rod_id,#{arg_type} value){
        |  VALUE klass;
        |  #{struct_name} * pointer;
        |#ifdef __BYTE_ORDER
        |#  if __BYTE_ORDER == __BIG_ENDIAN
        |  uint64_t value_swapped;
        |#  endif
        |#endif
        |
        |  if(object_rod_id == 0){
        |    rb_raise(rodException(), "Invalid object rod_id (0)");
        |  }
        |  klass = rb_funcall(self,rb_intern("class"),0);
        |  pointer = (#{struct_name} *)
        |    NUM2ULONG(rb_funcall(klass,rb_intern("rod_pointer"),0));
        |  if(pointer == 0){
        |    rb_raise(rodException(), "Invalid model pointer (0). DB is closed.");
        |  }
        |#ifdef __BYTE_ORDER
        |#  if __BYTE_ORDER == __BIG_ENDIAN
        |  // TODO #220 #221
        |  value_swapped = bswap_64(*((uint64_t *)((char *)&value)));
        |  (pointer + object_rod_id - 1)->#{name} = value_swapped;
        |#  else
        |  (pointer + object_rod_id - 1)->#{name} = value;
        |#  endif
        |#else
        |  (pointer + object_rod_id - 1)->#{name} = value;
        |#endif
        |}
        END
        builder.c(str.margin)
      end

      # Returns the size of the C type.
      def sizeof(type)
        # TODO implement
        0
      end

      # Returns the C type for given Rod type.
      def c_type(type)
        TYPE_MAPPING[type]
      end
    end
  end
end
