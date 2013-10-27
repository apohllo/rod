require 'yaml'
require 'rod/index/base'
require 'rod/utils'

module Rod
  module Database
    # This class implements the database abstraction, i.e. it
    # is a mediator between some model (a set of resources) and
    # the code, implementing the data storage functionality.
    class Base
      # TODO some of these should be converted to separate classes
      # with their own responsiblities.
=begin
      include Migration
=end
      include Utils

      # The meta-data of the DataBase.
      attr_reader :metadata

      # The path to the database directory.
      attr_reader :path

      # The id of the database. It is used to bind the resources
      # with databases.
      attr_reader :id

      # The resource space is used to link the resources with databases.
      # In normal circumstances there is only one resource space for all
      # databases.
      attr_reader :resource_space

      # The containers associated with this database used to store individual
      # resources.
      attr_reader :containers

      # Initializes the database with the options.
      # Options:
      # * +:metadata_factory+ - the factory used to create the database metadata instance.
      # * +:resource_metadata_factory+ - the factory used to create the
      #   resource metadata instances.
      # * +:resource_space_factory+ - the factory used to create the resource space.
      def initialize(id=:default,metadata_factory: Metadata::Metadata,
                    resource_metadata_factory: Metadata::ResourceMetadata,
                    resource_space_factory: Model::ResourceSpace,
                    registry_factory: Registry,
                    container_factory: Native::Container)
        @id = id
        @metadata_factory = metadata_factory
        @resource_metadata_factory = resource_metadata_factory
        @container_factory = container_factory
        @resource_space = resource_space_factory.instance
        @registry = registry_factory.instance
        @registry.register_database(self)
        @opened = false
      end

      # Returns diagnostic information about the database.
      def inspect
        "#{self.class}:#{self.object_id}:#{@handler} " +
          "readonly:#{readonly_data?} path:#{path}"
      end

      #########################################################################
      # Public API
      #########################################################################

      # Returns whether the database is opened.
      def opened?
        @opened
      end

      # The DB open mode.
      def readonly_data?
        @readonly
      end

      # Creates the database at specified +path+, which allows
      # for Rod::Model::Resource#store calls to be performed.
      #
      # The database is created for all resources, which have this
      # database configured via Rod::Model::Resource#database_id call
      # (this configuration is by default inherited in including resources,
      # so it have to be called only in the root class of a given model).
      #
      # WARNING: all files in the DB directory are removed during DB creation!
      def create(path)
        if block_given?
          self.create(path)
          begin
            yield
          ensure
            self.close
          end
        else
          create_without_block(path)
        end
      end

      # Opens the database on given +path+. This allows
      # for Rod::Model::Resource.count, Rod::Model::Resource.each, and similar calls.
      # Options:
      # * +:readonly+ - no modifiaction (append of models and has many association)
      #   is allowed (defaults to +true+). This option is ignored if create is called.
      # * +:generate+ - value could be true or a module. If present, generates
      #   the classes from the database metadata. If module given, the classes
      #   are generated within the module.
      # * +:migrate+ - migrate the database to new schema.
      def open(path,options={})
        if block_given?
          self.open(path,options)
          begin
            yield
          ensure
            self.close
          end
        else
          open_without_block(path,options)
        end
      end

      # Closes the database.
      #
      # If the +purge_resources+ flag is set to true, the information about the resources
      # linked with this database is removed. This is important for testing, when
      # resources with same names have different definitions.
      #
      # If the +skip_indeces+ is set to true, the indices are not stored.
      def close(purge_resources=false,skip_indices=false)
        raise DatabaseError.new("Database not opened.") unless opened?

        unless readonly_data?
          if referenced_objects.count{|k, v| not v.empty?} != 0
            raise DatabaseError.new("Not all associations have been stored: " +
                                    "#{referenced_objects.size} objects")
          end
          # XXX this is not exactly the behavior required
          unless skip_indices
            containers.each(&:close)
          end
          @metadata.store
        end
        resources_space.clear if purge_resources
        @opened = false
      end

      # The resources connected with this database.
      def resources
        @registry.resources_for(@id)
      end

      # Returns container for the specified +resource+.
      def container_for(resource)
        @registry.find_container_by_resource(resource,self.id)
      end

      protected

      # "Stack" of objects which are referenced by other objects during store,
      # but are not yet stored.
      def referenced_objects
        @referenced_objects ||= {}
      end

      # Retruns the path to the DB as a name of a directory.
      def canonicalize_path(path)
        path += "/" unless path[-1] == "/"
        path
      end

      private
      def open_without_block(path,readonly: true,**options)
        raise DatabaseError.new("Database already opened.") if opened?
        @path = canonicalize_path(path)
        @options = options
        @metadata = @metadata_factory.load(self,@resource_metadata_factory)
        @readonly = readonly
        @containers = @registry.resources_for(self.id).map do |resource|
          @container_factory.new(File.join(path,Utils.struct_name_for(resource)),
                                 resource,@metadata.resource_metadata(resource),
                                 readonly: @readonly)
        end
        @registry.register_containers(self)
        @containers.each{|c| c.open }
=begin
        if options[:generate]
          module_instance = (options[:generate] == true ? Object : options[:generate])
          @metadata.generate_resources(module_instance)
        end
        @metadata.configure_resources(options[:generate] || options[:migrate])
=end
        @opened = true
      end

      def create_without_block(path)
        raise DatabaseError.new("Database already opened.") if opened?
        @path = canonicalize_path(path)
        @metadata = @metadata_factory.new(self,@resource_metadata_factory)
        @readonly = false
        if File.exist?(@metadata.path)
          remove_file(@metadata.path)
        else
          FileUtils.mkdir_p(@path)
        end
        @containers = @registry.resources_for(self.id).map do |resource|
          @container_factory.new(File.join(path,Utils.struct_name_for(resource)),
                                 resource,@metadata.resource_metadata(resource),
                                 readonly: @readonly)
        end
        @registry.register_containers(self)
        @containers.each{|c| c.open }
=begin
        resources.each do |resource|
          resource.indices.each{|i| i.destroy }
        end
=end
        @opened = true
      end
    end
  end
end
