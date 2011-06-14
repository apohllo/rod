module Rod
  class JoinElement
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

    def self.path_for_data(path)
      "#{path}#{self.struct_name}.dat"
    end

    def self.page_offsets
      @page_offsets ||= []
    end

    def self.fields
      []
    end

    def self.build_structure
      # does nothing, the structure is not needed
    end

    def self.cache
      @cache ||= Cache.new
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
