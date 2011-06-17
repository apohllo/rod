require 'rod/abstract_model'

module Rod
  class StringElement < AbstractModel
    def self.typedef_struct
      ""
    end

    def self.struct_name
      "char"
    end
  end
end
