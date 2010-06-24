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

    def self.page_offsets
      @page_offsets ||= []
    end

    def self.fields
      []
    end
  end
end
