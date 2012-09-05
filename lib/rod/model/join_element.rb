require 'rod/model/simple_resource'

module Rod
  module Model
    class JoinElement
      extend SimpleResource
      extend NameConversion

      def self.typedef_struct
        str = <<-END
        |typedef struct {
        |  unsigned long offset;
        |  unsigned long index;
        |} _join_element;
        END
        Utils.remove_margin(str)
      end

      def self.layout
        '  printf("  offset: %lu, index: %lu\n",' +
          '(unsigned long)sizeof(unsigned long), ' +
          '(unsigned long)sizeof(unsigned long));' + "\n"
      end

      def self.struct_name
        "_join_element"
      end
    end

    class PolymorphicJoinElement < JoinElement
      def self.typedef_struct
        str = <<-END
        |typedef struct {
        |  unsigned long offset;
        |  unsigned long index;
        |  unsigned long class;
        |} _polymorphic_join_element;
        END
        Utils.remove_margin(str)
      end

      def self.struct_name
        "_polymorphic_join_element"
      end

      def self.layout
        '  printf("  offset: %lu, index: %lu, class: %lu\n",' +
          '(unsigned long)sizeof(unsigned long), ' +
          '(unsigned long)sizeof(unsigned long), ' +
          '(unsigned long)sizeof(unsigned long));' + "\n"
      end
    end
  end
end
