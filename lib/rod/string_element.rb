module Rod
  class StringElement
    def self.page_offsets
      @page_offsets ||= []
    end

    def self.typedef_struct
      #"typedef struct {char value;} _string_element;"
      ""
    end

    def self.struct_name
      #"_string_element"
      "char"
    end

    def self.path_for_data(path)
      "#{path}#{self.struct_name}.dat"
    end


    def self.layout
    end

    def self.fields
      []
    end

    def self.build_structure
      # does nothing, the structure is not needed
    end

    def self.cache
      @cache ||= SimpleWeakHash.new
    end
  end
end
