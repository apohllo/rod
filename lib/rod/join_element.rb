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

    def self.struct_name
      "_join_element"
    end

    def self.page_offsets
      # the join element class is takes the second page 
      # (the first is left for class stats)
      @page_offsets ||= [1]
    end
  end
end
