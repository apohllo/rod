require 'rod/abstract_model'

module Rod
  class JoinElement < AbstractModel
    def self.typedef_struct
      str = <<-END
      |typedef struct {
      |  unsigned long offset;
      |  unsigned long index;
      |} _join_element;
      END
      str.margin
    end

    def self.layout
      '  printf("  offset: %lu, index: %lu\n",sizeof(unsigned long), sizeof(unsigned long));' + "\n"
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
      str.margin
    end

    def self.struct_name
      "_polymorphic_join_element"
    end

    def self.layout
      '  printf("  offset: %lu, index: %lu, class: %lu\n",' +
        'sizeof(unsigned long), sizeof(unsigned long), sizeof(unsigned long));' + "\n"
    end
  end
end
