# encoding: utf-8

module Rod
  module Model
    class StringElement
      extend SimpleResource

      def self.typedef_struct
        ""
      end

      def self.struct_name
        "char"
      end
    end
  end
end
