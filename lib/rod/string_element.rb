module Rod
  class StringElement
    def self.page_offsets
      # the string element class takes the third page 
      # (the first is left for class stats, the second for join elements)
      @page_offsets ||= [2]
    end

    def self.typedef_struct
      #"typedef struct {char value;} _string_element;"
      ""
    end

    def self.struct_name
      #"_string_element"
      "char"
    end
  end
end
