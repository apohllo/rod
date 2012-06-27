require 'rod/abstract_model'

module Rod
  class Model < AbstractModel
    class StringElement < AbstractModel
      def self.typedef_struct
        ""
      end

      def self.struct_name
        "char"
      end
    end
  end
end
