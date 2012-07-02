# encoding: utf-8

module Rod
  module Model
    module Generation
      # Generates the model class based on the metadata and places
      # it in the +module_instance+ or Object (default scope) if module is nil.
      def self.generate_class(class_name,metadata)
        superclass = metadata[:superclass].constantize
        namespace = define_context(class_name)
        klass = Class.new(superclass)
        namespace.const_set(class_name.split("::")[-1],klass)
        [:fields,:has_one,:has_many].each do |type|
          (metadata[type] || []).each do |name,options|
            next if superclass.property(name)
            if type == :fields
              internal_options = options.dup
              field_type = internal_options.delete(:type)
              klass.send(:field,name,field_type,internal_options)
            else
              klass.send(type,name,options)
            end
          end
        end
        klass
      end

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
