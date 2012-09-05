# encoding: utf-8

module Rod
  module Model
    module Generation
      # Defines the namespace (contex) for given +class_name+ - if the constants
      # (modules and classes) are defined, they are just digged into,
      # if not - they are defined as modules.
      def self.define_context(class_name)
        class_name.split("::")[0..-2].inject(Object) do |mod,segment|
          begin
            mod.const_get(segment,false)
          rescue NameError
            new_mod = Module.new
            mod.const_set(segment,new_mod)
            new_mod
          end
        end
      end
    end
  end
end
