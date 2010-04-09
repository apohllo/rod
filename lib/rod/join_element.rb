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
  end
end
