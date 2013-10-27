require 'rod/model/name_conversion'

module Rod
  module Metadata
    # The Resource meta-data class provides metadata abstraction
    # for resources. The meta-data stores information
    # about various aspects of the resource allowing for
    # checking if the runtime resource definition is compatible
    # with the database resource definition as well as for
    # re-generating the resource in order to get the access to
    # the data, even if the resource (i.e. Ruby class)
    # definition is not available.
    class ResourceMetadata
      # The meta-data as a map.
      attr_reader :data

      # The data should is only accessible to the other Metadata instances.
      protected :data

      # The resource this meta-data is created for.
      attr_accessor :resource

      # The name of the resource.
      attr_accessor :name

      # Options:
      # * :resource: the resource this metadata is created for
      # * :descriptor: hash used to initialize the metadata
      # * :name_coverter: service used to convert names of resources
      # One of +resource+ or +descriptor+ must be present in order to create
      # the metadata.
      def initialize(resource: resource,descriptor: nil, name_converter: Model::NameConversion)
        if resource.nil? && descriptor.nil?
          raise RodException.new("Empty resource for the resource metadata")
        end

        @resource = resource
        @name_converter = name_converter
        if descriptor
          from_hash(descriptor)
        else
          initialize_empty
        end
        gather_property_metadata if descriptor.nil?
      end

      # Returns the metadata as a string.
      def inspect
        "#{@name} #{@data.inspect}"
      end

      # Returns the number of instances for the class.
      def element_count
        @data[:element_count]
      end

      # Returns the number of bytes occupied by the variable lenght
      # structures.
      def byte_count
        @data[:byte_count]
      end

      # Returns the number of indirectly referenced monomorphic elements.
      def monomorphic_count
        @data[:monomorphic_count]
      end

      # Returns the number of indirectly referenced polymorphic elements.
      def polymorphic_count
        @data[:polymorphic_count]
      end

      # The relative path to the resource withing the database.
      # It might be only partially based on its name, since there
      # are resources that might be scoped in a module, still referencing
      # an unscoped resource path.
      def model_path
        # TODO move name conversion to the metadata class.
        @model_path ||= Utils.struct_name_for(@name)
      end

      # Returns the parent resource (superclass) of the resource.
      def parent
        @data[:superclass]
      end

      # TODO Remove this when #238 is implemented.
      alias superclass parent

      def to_hash(container)
        @data[:element_count] = container.element_count
        @data[:byte_count] = container.byte_count
        @data[:monomorphic_count] = container.monomorphic_count
        @data[:polymorphic_count] = container.polymorphic_count
        Marshal.load(Marshal.dump(@data))
      end

      # Checks if the +other+ meta-data are compatible with these meta-data.
      def check_compatibility(other)
        if self.name != other.name
          raise IncompatibleClass.
            new("Incompatible resources #{self.name} vs. #{other.name}")
        end
        unless self.difference(other).empty?
          raise IncompatibleClass.
            new("Incompatible definition of '#{self.name}' class.\n" +
                "Database and runtime versions are different:\n  " +
                self.difference(other).
                map{|e1,e2| "DB: #{e1} vs. RT: #{e2}"}.join("\n  "))
        end
        true
      end

      # Calculates the difference between this meta-data
      # and the +other+ metadata.
      def difference(other)
        result = []
        @data.each do |type,values|
          next if type == :count
          if Property::ClassMethods::ACCESSOR_MAPPING.keys.include?(type)
            # properties
            values.to_a.zip(other.data[type].to_a) do |meta1,meta2|
              if meta1 != meta2
                result << [meta2,meta1]
              end
            end
          else
            # other stuff
            if other.data[type] != values
              result << [other.data[type],values]
            end
          end
        end
        result
      end

      # Generates the resource using these meta-data.
      def generate_resource
        parent_resource = @data[:superclass].constantize
        namespace = Model::Generation.define_context(self.name)
        @resource = Class.new(parent_resource)
        namespace.const_set(self.name.split("::")[-1],@resource)
        # Generate the properties defined in the meta-data.
        Property::ClassMethods::ACCESSOR_MAPPING.keys.each do |type|
          (@data[type] || []).each do |name,options|
            # We do not call the macro functions for properties defined
            # in the parent resources.
            next if parent_resource.property(name)
            # TODO Delegate this code to PropertyMetadata class.
            if type == :field
              internal_options = options.dup
              field_type = internal_options.delete(:type)
              @resource.send(type,name,field_type,internal_options)
            else
              @resource.send(type,name,options)
            end
          end
        end
        # TODO this should be moved elsewhere.
        @resource.model_path = self.model_path
        @database.add_class(@resource)
        @resource.__send__(:database_class,@database.class)
      end

      # This method adds a +prefix+ (a module or modules) to the
      # resources that are referenced by this meta-data.
      #
      # Only the resources that are present in the +dependency_tree+
      # are changed, i.e. only the resource which the prefix should
      # be accomodated for.
      def add_prefix(prefix,dependency_tree)
        # call model_path to preserve its value, this is a code smell
        self.model_path
        @name = prefix + @name
        if dependency_tree.present?(@data[:superclass])
          @data[:superclass] = prefix + @data[:superclass]
        end
        Property::ClassMethods::ACCESSOR_MAPPING.keys.each do |type|
          next if @data[type].nil?
          @data[type].each do |property,options|
            if dependency_tree.present?(options[:class_name])
              @data[type][property][:class_name] = prefix + options[:class_name]
            end
          end
        end
      end

      private
      def from_hash(hash)
        @data = hash
        @name = hash.delete(:name)
      end

      def initialize_empty
        @data = {}
        @data[:name_hash] = @name_converter.name_hash(@resource)
        @data[:superclass] = @resource.superclass.name
        @data[:element_count] = 0
        @data[:byte_count] = 0
        @data[:monomorphic_count] = 0
        @data[:polymorphic_count] = 0
        @name = resource.name
      end

      def registry_factory
        Registry
      end

      def gather_property_metadata
        Property::ClassMethods::ACCESSOR_MAPPING.each do |accessor_type,accessor_method|
          property_group_data = {}
          resource.send(accessor_method).each do |property|
            next if property.to_hash.empty?
            property_group_data[property.name] = property.to_hash
          end
          unless property_group_data.empty?
            @data[accessor_type] = property_group_data
          end
        end
      end
    end
  end
end
