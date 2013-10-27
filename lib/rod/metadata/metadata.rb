# encoding: utf-8
require_relative 'dependency_tree'

module Rod
  module Metadata
    # The meta-data describing the database.
    # These meta-data cover info such as:
    # * the version of the ROD library
    # * the creation/update time of the DB
    # * the meta-data of the classes that are stored in the DB
    # The class is used to:
    # * convert the resources to their description
    # * convert the description to the resources
    # * convert the description to an external format (YAML)
    class Metadata
      # The name of file containing the database meta-data.
      METADATA_FILE = "database.yml"

      # The key used to store the database-related metadata (the meta-data
      # not related to any class).
      ROD_KEY = "Rod"

      # The database instance which the meta-data is created for.
      attr_reader :database

      # The factory used to create the meta-data for the individual
      # resources.
      attr_accessor :metadata_factory

      # The clock used to set the creation and update time of the metadata.
      attr_accessor :clock

      # Initialize the meta-data with the DB it is created for.
      #
      # The second argument is the factory used to build the meta-data
      # for the resources, that parts of the meta-data for the database.
      #
      # The creation time might be provided by the +clock+ option,
      # which is a factory for the time. By default this is a real clock.
      #
      # The last argument is a descriptor that is used to initialize the
      # fields of the metadata (if provided).
      def initialize(database,metadata_factory,clock=Time,descriptor=nil)
        @database = database
        @metadata_factory = metadata_factory
        @clock = clock
        if descriptor
          from_hash(descriptor)
        else
          initialize_default(database.resources)
        end
      end

      # Returns the metadata as a string.
      def inspect
        @data.inspect
      end

      # Returns the version of the meta-data.
      def version
        @data[ROD_KEY][:version]
      end

      # Set the version of the metadata.
      def version=(value)
        @data[ROD_KEY][:version] = value
      end

      # Returns the database creation time.
      def created_at
        @data[ROD_KEY][:created_at]
      end

      # Returns the database update time.
      def updated_at
        @data[ROD_KEY][:updated_at]
      end

      # Assign a +database+ to the metadata. This call propagates
      # to the dependent meta-data.
      def database=(database)
        @database = database
        @data.each do |key,metadata|
          next if key == ROD_KEY
          metadata.database = @database
        end
      end

      # Returns the metadata loaded from the database's metadata file.
      # Raises exception if the version of the library and the database are
      # not compatible.
      #
      # The +metadata_factory+ is used to create the meta-data for
      # the individual resources that are connected with the DB.
      #
      # If the +input_factory+ is given, it is used
      # to create the input stream used to load the meta-data. By defaul it is a +File+.
      def self.load(database,metadata_factory,input_factory=File)
        metadata = nil
        input_factory.open(self.new(database,metadata_factory).path) do |input|
          metadata = self.new(database,metadata_factory,Time,YAML.load(input))
        end
        raise IncompatibleVersion.new("Incompatible versions - library #{VERSION} vs. " +
                                      "file #{metadata.version}") unless metadata.valid?
        metadata
      end

      # Stores the metadata in YAML using the +output_factory+ (File by
      # default).
      def store(output_factory=File)
        File.open(path,"w"){|o| o.puts(YAML.dump(self.to_hash)) }
      end

      # Converts itself to hash.
      def to_hash
        copy = @data.clone
        copy[ROD_KEY][:updated_at] = @clock.now
        copy.each do |key,value|
          next if key == ROD_KEY
          copy[key] = value.to_hash(@database.container_for(key.constantize))
        end
        copy
      end

      # The location of the meta-data file.
      def path
        @database.path + METADATA_FILE
      end

      # Checks if the version of the library is valid.
      # Consult https://github.com/apohllo/rod/wiki for the versioning scheme.
      #
      # If the +library_version+ is provided, the meta-data is checked against it.
      def valid?(library_version=VERSION)
        file = version.split(".")
        library = library_version.split(".")
        return false if file[0] != library[0] || file[1] != library[1]
        if library[1].to_i.even?
          return file[2].to_i <= library[2].to_i
        else
          return file[2] == library[2]
        end
      end

=begin
      # Configures the resources connected with the database using
      # the meta-data.
      #
      # If +skip_resource_check+ is true, the resource compatiblity
      # check is not performed. This is needed for migration and
      # model generation.
      def configure_resources(skip_resource_check=false)
        data = @data.dup
        data.delete(ROD_KEY)
        @database.classes.each do |resource|
          resource_data = data.delete(resource.name)
          if resource_data.nil?
            # new class
            next
          end
          resource_data.resource = resource
          unless skip_resource_check
            resource_data.check_compatibility(metadata_factory.new(resource: resource))
          end
          @database.configure_count(resource,resource_data.count)
        end
        if data.size > 0
          raise DatabaseError.new("The following classes are missing in runtime:\n - " +
                                  data.keys.join("\n - "))
        end
      end

      # Generate the resources using these meta-data as their configuration.
      # The +module_instance+ is used as the context of the resources,
      # so two sets of resources with same names can exist in the same time.
      def generate_resources(module_instance)
        prefix = module_instance == Object ? "" : module_instance.name + "::"
        add_prefix(prefix) unless prefix.empty?
        dependency_tree.sorted.each{|r| @data[r].generate_resource}
      end
=end

      # Returns the meta-data only for the regular resources
      # (excluding the DB and simple resources meta-data).
      def resources
        Hash[@data.reject{|r,o| r == ROD_KEY}]
      end

      # Returns the metadata for a given +resource+.
      def resource_metadata(resource)
        @data[resource.to_s]
      end

      # Returns the dependency tree of the resources in the
      # database which the meta-data is created for.
      # This method accepts the dependency_tree_factory which
      # is used to create the dependency tree. It is the DependencyTree
      # class by default.
      def dependency_tree(dependency_tree_factory=DependencyTree)
        dependency_tree_factory.new(self)
      end

      # This method adds a +prefix+ (a module or modules) to the
      # resources that are described by the meta-data.
      def add_prefix(prefix)
        original_tree = dependency_tree
        original_tree.sorted.each do |resource_name|
          resource_data = @data.delete(resource_name)
          resource_data.add_prefix(prefix,original_tree)
          @data[prefix + resource_name] = resource_data
        end
      end


      private
      # Convert the +hash+ to the metadata.
      def from_hash(hash)
        @data = hash
        @data.each do |key,value|
          next if key == ROD_KEY
          value[:name] = key
          @data[key] = metadata_factory.new(descriptor:value)
        end
      end

      # Initialize default metadata.
      def initialize_default(resources)
        @data = {}
        @data[ROD_KEY] = {}
        @data[ROD_KEY][:version] = VERSION
        @data[ROD_KEY][:created_at] = @clock.now
        resources.each do |resource|
          @data[resource.name] = metadata_factory.new(resource:resource)
        end
      end

      # Creates deep copy of the hash.
      def deep_hash_copy(hash)
        Marshal.load(Marshal.dump(hash))
      end
    end
  end
end
