module Rod
  module Property
    class VirtusAdapter
      TYPE_MAPPING = Hash.new(:object).merge({
        Integer => :integer,
        Float => :float,
        String => :string
      }).freeze

      # Convert Virtus +attribute+ to appropriate call on the +resource+.
      def convert_attribute(attribute,resource)
        options = attribute.options
        if options[:primitive] < Virtus || options[:primitive] == Object
          convert_association(attribute.name,options,resource,:singular)
        else
          type = options[:primitive].to_s
          case type
          when "Integer", "Float", "String"
            convert_field(attribute.name,options,resource)
          when "Array"
            convert_association(attribute.name,options,resource,:plural)
          else
            convert_field(attribute.name,options,resource)
          end
        end
      end

      private
      def convert_field(name,options,resource)
        type = TYPE_MAPPING[options[:primitive]]
        resource.__send__(:field,name,type,convert_options(options))
      end

      def convert_association(name,options,resource,arity)
        resource_method = (arity == :singular ? :has_one : :has_many)
        rod_options = convert_options(options)
        rod_options[:polymorphic] = true if polymorphic_association?(options)
        resource.__send__(resource_method,name,rod_options)
      end

      def convert_options(options)
        rod_options = {}
        rod_options[:index] = options[:index] if options[:index]
        rod_options[:order] = options[:order] if options[:order]
        rod_options
      end

      def polymorphic_association?(options)
        options[:primitive] == Object || options[:member_type] == Object
      end
    end
  end
end
