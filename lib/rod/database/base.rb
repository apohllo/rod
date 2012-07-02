require 'singleton'
require 'yaml'
require 'rod/index/base'
require 'rod/utils'

module Rod
  module Database
    # This class implements the database abstraction, i.e. it
    # is a mediator between some model (a set of classes) and
    # the code, implementing the data storage functionality.
    class Base
      # This class is a singleton, since in a given time instant there
      # is only one database (one file/set of files) storing data of
      # a given model (set of classes).
      include Singleton

      # TODO some of these should be converted to separate objects
      # with their own responsiblities.
      include ClassSpace
      include Generation
      include Migration
      include Metadata
      include Utils

      # The meta-data of the DataBase.
      attr_reader :metadata

      # The path which the database instance is located on.
      attr_reader :path

      # This flag indicates, if Database and Model works in development
      # mode, i.e. the dynamically loaded library has a unique, different id each time
      # the rod library is used.
      @@rod_development_mode = false

      # Initializes the classes linked with this database and the handler.
      def initialize
        @classes ||= self.special_classes
        @handler = nil
      end

      # Writer of the +rod_development_mode+ flag.
      def self.development_mode=(value)
        @@rod_development_mode = value
      end

      # Reader of the +rod_development_mode+ flag.
      def self.development_mode
        @@rod_development_mode
      end

      #########################################################################
      # Public API
      #########################################################################

      # Returns whether the database is opened.
      def opened?
        not @handler.nil?
      end

      # The DB open mode.
      def readonly_data?
        @readonly
      end

      # Creates the database at specified +path+, which allows
      # for Rod::Model::Resource#store calls to be performed.
      #
      # The database is created for all classes, which have this
      # database configured via Rod::Model::Resource#database_class call
      # (this configuration is by default inherited in including classes,
      # so it have to be called only in the root class of given model).
      #
      # WARNING: all files in the DB directory are removed during DB creation!
      def create_database(path)
        if block_given?
          create_database(path)
          begin
            yield
          ensure
            close_database
          end
        else
          raise DatabaseError.new("Database already opened.") if opened?
          @readonly = false
          @path = canonicalize_path(path)
          if File.exist?(@path)
            remove_file("#{@path}database.yml")
          else
            FileUtils.mkdir_p(@path)
          end
          self.classes.each do |klass|
            klass.__send__(:build_structure)
            remove_file(klass.path_for_data(@path))
            next if special_class?(klass)
            klass.indexed_properties.each do |property|
              property.index.destroy
            end
            remove_files_but(klass.inline_library)
          end
          remove_files(self.inline_library)
          generate_c_code(@path, classes)
          remove_files_but(self.inline_library)
          @metadata = {}
          @metadata["Rod"] = {}
          @metadata["Rod"][:created_at] = Time.now
          @handler = _init_handler(@path)
          _create(@handler)
        end
      end

      # Opens the database at +path+ with +options+. This allows
      # for Rod::Model::Resource.count, Rod::Model::Resource.each, and similar calls.
      # Options:
      # * +:readonly+ - no modifiaction (append of models and has many association)
      #   is allowed (defaults to +true+)
      # * +:generate+ - value could be true or a module. If present, generates
      #   the classes from the database metadata. If module given, the classes
      #   are generated withing the module.
      def open_database(path,options={:readonly => true})
        raise DatabaseError.new("Database already opened.") if opened?
        options = convert_options(options)
        @readonly = options[:readonly]
        @path = canonicalize_path(path)
        @metadata = load_metadata
        if options[:generate]
          module_instance = (options[:generate] == true ? Object : options[:generate])
          generate_classes(module_instance)
        end
        self.classes.each do |klass|
          klass.send(:build_structure)
          next if special_class?(klass)
          if options[:generate] && module_instance != Object
            remove_files_but(klass.inline_library)
          end
        end
        generate_c_code(@path, self.classes)
        @handler = _init_handler(@path)
        metadata_copy = @metadata.dup
        metadata_copy.delete("Rod")
        self.classes.each do |klass|
          meta = metadata_copy.delete(klass.name)
          if meta.nil?
            # new class
            next
          end
          unless klass.compatible?(meta) || options[:generate] || options[:migrate]
              raise IncompatibleVersion.
                new("Incompatible definition of '#{klass.name}' class.\n" +
                    "Database and runtime versions are different:\n  " +
                    klass.difference(meta).
                    map{|e1,e2| "DB: #{e1} vs. RT: #{e2}"}.join("\n  "))
          end
          set_count(klass,meta[:count])
          file_size = File.new(klass.path_for_data(@path)).size
          unless file_size % _page_size == 0
            raise DatabaseError.new("Size of data file of #{klass} is invalid: #{file_size}")
          end
          set_page_count(klass,file_size / _page_size)
        end
        if metadata_copy.size > 0
          @handler = nil
          raise DatabaseError.new("The following classes are missing in runtime:\n - " +
                                  metadata_copy.keys.join("\n - "))
        end
        _open(@handler)
      end

      # Closes the database.
      #
      # If the +purge_classes+ flag is set to true, the information about the classes
      # linked with this database is removed. This is important for testing, when
      # classes with same names have different definitions.
      #
      # If the +skip_indeces+ flat is set to true, the indices are not written.
      def close_database(purge_classes=false,skip_indices=false)
        raise DatabaseError.new("Database not opened.") unless opened?

        unless readonly_data?
          unless referenced_objects.select{|k, v| not v.empty?}.size == 0
            raise DatabaseError.new("Not all associations have been stored: #{referenced_objects.size} objects")
          end
          unless skip_indices
            self.classes.each do |klass|
              next if special_class?(klass)
              klass.indexed_properties.each do |property|
                property.index.save
              end
            end
          end
          write_metadata
        end
        _close(@handler)
        @handler = nil
        # clear cached data
        self.clear_cache
        #debugger
        if purge_classes
          @classes = self.special_classes
        end
      end

      # Clears the cache of the database.
      def clear_cache
        classes.each{|c| c.cache.clear }
      end

      #########################################################################
      # Calls that are delegated to the implementation layer.
      #########################################################################

      # Returns join index with +index+ and +offset+.
      def join_index(offset, index)
        _join_element_index(offset, index, @handler)
      end

      # Returns polymorphic join index with +index+ and +offset+.
      # This is the rod_id of the object referenced via
      # a polymorphic has many association for one instance.
      def polymorphic_join_index(offset, index)
        _polymorphic_join_element_index(offset, index, @handler)
      end

      # Returns polymorphic join class id with +index+ and +offset+.
      # This is the class_id (name_hash) of the object referenced via
      # a polymorphic has many association for one instance.
      def polymorphic_join_class(offset, index)
        _polymorphic_join_element_class(offset, index, @handler)
      end

      # Sets the +object_id+ of the join element with +offset+ and +index+.
      def set_join_element_id(offset,index,object_id)
        raise DatabaseError.new("Readonly database.") if readonly_data?
        _set_join_element_offset(offset, index, object_id, @handler)
      end

      # Sets the +object_id+ and +class_id+ of the
      # polymorphic join element with +offset+ and +index+.
      def set_polymorphic_join_element_id(offset,index,object_id,class_id)
        raise DatabaseError.new("Readonly database.") if readonly_data?
        _set_polymorphic_join_element_offset(offset, index, object_id,
                                             class_id, @handler)
      end

      # Allocates space for polymorphic join elements.
      def allocate_polymorphic_join_elements(size)
        raise DatabaseError.new("Readonly database.") if readonly_data?
        _allocate_polymorphic_join_elements(size,@handler)
      end

      # Allocates space for join elements.
      def allocate_join_elements(size)
        raise DatabaseError.new("Readonly database.") if readonly_data?
        _allocate_join_elements(size,@handler)
      end

      # Computes fast intersection for sorted join elements.
      def fast_intersection_size(first_offset,first_length,second_offset,second_length)
        _fast_intersection_size(first_offset,first_length,second_offset,
                                second_length,@handler)
      end

      # Returns the string of given +length+ starting at given +offset+.
      def read_string(length, offset)
        value = _read_string(length, offset, @handler)
      end

      # Stores the string in the DB.
      def set_string(value)
        raise DatabaseError.new("Readonly database.") if readonly_data?
        _set_string(value,@handler)
      end

      # Returns the number of objects for given +klass+.
      def count(klass)
        send("_#{klass.struct_name}_count",@handler)
      end

      # Sets the number of objects for given +klass+.
      def set_count(klass,value)
        send("_#{klass.struct_name}_count=",@handler,value)
      end

      # Sets the number of pages allocated for given +klass+.
      def set_page_count(klass,value)
        send("_#{klass.struct_name}_page_count=",@handler,value)
      end

      # Store the object in the database.
      def store(klass,object)
        raise DatabaseError.new("Readonly database.") if readonly_data?
        if object.new?
          send("_store_" + klass.struct_name,object,@handler)
        end
      end

      # Prints the layout of the pages in memory and other
      # internal data of the model.
      def print_layout
        raise DatabaseError.new("Database not opened.") unless opened?
        _print_layout(@handler)
      end

      # Prints the last error of system call.
      def print_system_error
        _print_system_error
      end

      protected

      # "Stack" of objects which are referenced by other objects during store,
      # but are not yet stored.
      def referenced_objects
        @referenced_objects ||= {}
      end


      # Checks if the version of the library is valid.
      # Consult https://github.com/apohllo/rod/wiki for versioning scheme.
      def valid_version?(version)
        file = version.split(".")
        library = VERSION.split(".")
        return false if file[0] != library[0] || file[1] != library[1]
        if library[1].to_i.even?
          return file[2].to_i <= library[2].to_i
        else
          return file[2] == library[2]
        end
      end

      # Retruns the path to the DB as a name of a directory.
      def canonicalize_path(path)
        path += "/" unless path[-1] == "/"
        path
      end

      def convert_options(options)
        result = {}
        case options
        when true,false
          result[:readonly] = options
        when Hash
          result = options
        else
          raise RodException.new("Invalid options for open_database: #{options}!")
        end
        result[:readonly] = true if result[:readonly].nil?
        result
      end
    end
  end
end
