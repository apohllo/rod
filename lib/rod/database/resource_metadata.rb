module Rod
  module Database
    module ResourceMetadata
      # Builds the meta-data for the +resource+ given.
      #
      # If the +descriptor+ is provided it is used to setup the properties of the
      # meta-data. In that case the +resource+ might be nil, but should be
      # setup, before the metadata is used.
      def self.build(resource,database,descriptor=nil)
        if resource.included_modules.include?(Model::Resource)
          Resource.new(resource,database,descriptor)
        else
          SimpleResource.new(resource,database,descriptor)
        end
      end

      # The SimpleResource meta-data class provides metadata abstraction
      # for simple resources. The meta-data stores information
      # about various aspects of the resource allowing for
      # checking if the runtime resource definition is compatible
      # with the database resource definition as well as for
      # re-generating the resource in order to get the access to
      # the data, even if the resource (i.e. Ruby class)
      # definition is not available.
      class SimpleResource
        # The meta-data as a map.
        attr_reader :data

        # The data should is only accessible to the other Metadata instances.
        protected :data

        # The database this meta-data is connected with.
        attr_accessor :database

        # The resource this meta-data is created for.
        attr_accessor :resource

        # The name of the resource.
        attr_accessor :name

        # Initializes the metadata for a given +resource+ and a given +database+.
        def initialize(resource,database,descriptor=nil)
          raise RodException.new("Empty database for the resource metadata") if database.nil?
          if resource.nil? && descriptor.nil?
            raise RodException.new("Empty resource for the resource metadata")
          end

          @resource = resource
          @database = database
          if descriptor
            from_hash(descriptor)
          else
            initialize_empty
          end
        end

        # Returns the metadata as a string.
        def inspect
          "#{@name} #{@data.inspect}"
        end

        # Checks if the +other+ meta-data are compatible with these meta-data.
        # If the resource are not compatible, a IncompatibleClass exception is thrown.
        # +true+ is returned otherwise.
        def check_compatibility(other)
          if self.name != other.name
            raise IncompatibleClass.
              new("Incompatible resources #{self.name} vs. #{other.name}")
          end
          true
        end

        # Returns the number of instances for the class.
        def count
          @data[:count]
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

        def to_hash
          @data[:count] = @database.count(@resource)
          Marshal.load(Marshal.dump(@data))
        end

        private
        def from_hash(hash)
          @data = hash
          @name = hash.delete(:name)
        end

        def initialize_empty
          @data = {}
          @data[:name_hash] = @resource.name_hash
          @data[:superclass] = @resource.superclass.name
          @data[:count] = 0
          @name = resource.name
        end
      end

      # This class extends the simple resource meta-data with the information
      # that alows to check if the definition of a resource
      # in runtime is the same as the DB definition. It also
      # allows to recreate the resource (at least data access methods)
      # if its definition is not provided.
      class Resource < SimpleResource
        # Initialize the meta-data with the +resource+ and the +database+
        # it is created for.
        #
        # An optional +descriptor+ is used to initialized the meta-data values.
        def initialize(resource,database,descriptor=nil)
          super
          gather_property_metadata if descriptor.nil?
        end

        # Checks if the +other+ meta-data are compatible with these meta-data.
        def check_compatibility(other)
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
end
