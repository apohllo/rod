# encoding: utf-8

module Rod
  module Database
    module Generation
      # Generates the classes for the data using the metadata from database.yml
      # +module_instance+ is the module in which the classes are generated.
      # This allows for embedding them in a separate namespace and use the same model
      # with different databases in the same time.
      def generate_classes(module_instance)
        special_names = special_classes.map{|k| k.name}
        special_names << "Rod"
        superclasses = {}
        inverted_superclasses = {}
        @metadata.reject{|k,o| special_names.include?(k)}.each do |k,o|
          superclasses[k] = o[:superclass]
          inverted_superclasses[o[:superclass]] ||= []
          inverted_superclasses[o[:superclass]] << k
        end
        queue = inverted_superclasses["Rod::Model::Base"] || []
        sorted = []
        begin
          klass = queue.shift
          sorted << klass
          queue.concat(inverted_superclasses[klass] || [])
        end until queue.empty?
        sorted.each do |klass_name|
          metadata = @metadata[klass_name]
          original_name = klass_name
          if module_instance != Object
            prefix = module_instance.name + "::"
            if superclasses.keys.include?(metadata[:superclass])
              metadata[:superclass] = prefix + metadata[:superclass]
            end
            [:fields,:has_one,:has_many].each do |property_type|
              next if metadata[property_type].nil?
              metadata[property_type].each do |property,options|
                if superclasses.keys.include?(options[:class_name])
                  metadata[property_type][property][:class_name] =
                    prefix + options[:class_name]
                end
              end
            end
            # klass name
            klass_name = prefix + klass_name
            @metadata.delete(original_name)
            @metadata[klass_name] = metadata
          end
          klass = Model::Generation.generate_class(klass_name,metadata)
          klass.model_path = Model::NameConversion.struct_name_for(original_name)
          @classes << klass
          klass.__send__(:database_class,self.class)
        end
      end
    end
  end
end
