require 'singleton'
require 'yaml'
require 'rod/index/base'
require 'rod/utils'

module Rod
  # This class implements the database abstraction, i.e. it
  # is a mediator between some model (a set of classes) and
  # the generated C code, implementing the data storage functionality.
  class AbstractDatabase
    # This class is a singleton, since in a given time instant there
    # is only one database (one file/set of files) storing data of
    # a given model (set of classes).
    include Singleton

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
    # for Rod::Model#store calls to be performed.
    #
    # The database is created for all classes, which have this
    # database configured via Rod::Model#database_class call
    # (this configuration is by default inherited in subclasses,
    # so it have to be called only in the root class of given model).
    #
    # WARNING: all files in the DB directory are removed during DB creation!
    def create_database(path)
      raise DatabaseError.new("Database already opened.") if opened?
      @readonly = false
      @path = canonicalize_path(path)
      if File.exist?(@path)
        remove_file("#{@path}database.yml")
      else
        FileUtils.mkdir_p(@path)
      end
      self.classes.each do |klass|
        klass.send(:build_structure)
        remove_file(klass.path_for_data(@path))
        klass.indexed_properties.each do |property,options|
          klass.index_for(property,options).destroy
        end
        next if special_class?(klass)
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

    # Opens the database at +path+ with +options+. This allows
    # for Rod::Model.count, Rod::Model.each, and similar calls.
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
      @metadata = {}
      File.open(@path + DATABASE_FILE) do |input|
        @metadata = YAML::load(input)
      end
      unless valid_version?(@metadata["Rod"][:version])
        raise IncompatibleVersion.new("Incompatible versions - library #{VERSION} vs. " +
                                      "file #{metatdata["Rod"][:version]}")
      end
      if options[:generate]
        module_instance = (options[:generate] == true ? Object : options[:generate])
        generate_classes(module_instance)
      elsif options[:migrate]
        create_legacy_classes
        FileUtils.cp(@path + DATABASE_FILE, @path + DATABASE_FILE + LEGACY_DATA_SUFFIX)
        remove_files(self.inline_library)
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
      self.classes.each do |klass|
        meta = @metadata[klass.name]
        if meta.nil?
          # new class
          next
        end
        unless klass.compatible?(meta,self) || options[:generate] || options[:migrate]
            raise IncompatibleVersion.
              new("Incompatible definition of '#{klass.name}' class.\n" +
                  "Database and runtime versions are different:\n" +
                  "  #{meta}\n  #{klass.metadata(self)}")
        end
        set_count(klass,meta[:count])
        file_size = File.new(klass.path_for_data(@path)).size
        unless file_size % _page_size == 0
          raise DatabaseError.new("Size of data file of #{klass} is invalid: #{file_size}")
        end
        set_page_count(klass,file_size / _page_size)
        if options[:migrate]
          next unless klass.name =~ LEGACY_RE
          new_class = klass.name.sub(LEGACY_RE,"").constantize
          set_count(new_class,meta[:count])
          pages = (meta[:count] * new_class.struct_size / _page_size.to_f).ceil
          set_page_count(new_class,pages)
        end
      end
      _open(@handler)
      if options[:migrate]
        empty_data = "\0" * _page_size
        self.classes.each do |klass|
          next unless klass.to_s =~ LEGACY_RE
          new_class = klass.name.sub(LEGACY_RE,"").constantize
          old_metadata = klass.metadata(self)
          old_metadata.merge!({:superclass => old_metadata[:superclass].sub(LEGACY_RE,"")})
          unless new_class.compatible?(old_metadata,self)
            File.open(new_class.path_for_data(@path),"w") do |out|
              send("_#{new_class.struct_name}_page_count",@handler).
                times{|i| out.print(empty_data)}
            end
            klass.migrate
            current_file_name = klass.path_for_data(@path)
            legacy_file_name = current_file_name + LEGACY_DATA_SUFFIX
            new_file_name = new_class.path_for_data(@path)
            FileUtils.mv(current_file_name,legacy_file_name)
            FileUtils.mv(new_file_name,current_file_name)
          end
          @classes.delete(klass)
          new_class.model_path = nil
        end
        close_database(false,true)
        options.delete(:migrate)
        readonly = options.delete(:old_readonly)
        options[:readonly] = readonly
        open_database(path,options)
      end
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
            klass.indexed_properties.each do |property,options|
              write_index(klass,property,options)
            end
          end
        end
        write_metadata
      end
      _close(@handler)
      @handler = nil
      # clear cached data
      self.clear_cache
      if purge_classes
        @classes = self.special_classes
      end
    end

    # Clears the cache of the database.
    def clear_cache
      classes.each{|c| c.cache.clear }
    end

    #########################################################################
    # 'Private' API
    #########################################################################

    # "Stack" of objects which are referenced by other objects during store,
    # but are not yet stored.
    def referenced_objects
      @referenced_objects ||= {}
    end

    # Returns true if the class is one of speciall classes
    # (JoinElement, PolymorphicJoinElement, StringElement).
    def special_class?(klass)
      self.special_classes.include?(klass)
    end

    # Adds the +klass+ to the set of classes linked with this database.
    def add_class(klass)
      @classes << klass unless @classes.include?(klass)
    end

    # Remove the +klass+ from the set of classes linked with this database.
    def remove_class(klass)
      unless @classes.include?(klass)
        raise DatabaseError.new("Class #{klass} is not linked with #{self}!")
      end
      @classes.delete(klass)
    end

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

    # Returns the string of given +length+ starting at given +offset+.
    # Options:
    # * +:skip_encoding+ - if set to +true+, the string is left as ASCII-8BIT
    def read_string(length, offset,options={})
      # TODO the encoding should be stored in the DB
      # or configured globally
      value = _read_string(length, offset, @handler)
      if options[:skip_encoding]
        value.force_encoding("ascii-8bit")
      else
        value.force_encoding("utf-8")
      end
    end

    # Stores the string in the DB encoding it to utf-8.
    # Options:
    # * +:skip_encoding+ - if set to +true+, the string is not encoded
    def set_string(value,options={})
      raise DatabaseError.new("Readonly database.") if readonly_data?
      value = value.encode("utf-8") unless options[:skip_encoding]
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

    # Store index of +field+ (with +options+) of +klass+ in the database.
    # There are two types of indices:
    # * +:flat+ - marshalled index is stored in one file
    # * +:segmented+ - marshalled index is stored in many files
    def write_index(klass,property,options)
      raise DatabaseError.new("Readonly database.") if readonly_data?
      class_index = klass.index_for(property,options)
      if options[:convert]
        # Only convert the index, without (re)storing the values.
        index = Index::Base.create(klass.path_for_index(@path,property),klass,options)
        index.copy(class_index)
        class_index = index
      else
        class_index.each do |key,proxy|
          proxy.save
        end
      end
      class_index.save
      class_index = nil
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

    # Returns collected subclasses.
    def classes
      @classes.sort{|c1,c2| c1.to_s <=> c2.to_s}
    end

    # Retruns the path to the DB as a name of a directory.
    def canonicalize_path(path)
      path += "/" unless path[-1] == "/"
      path
    end

    # Special classes used by the database.
    def special_classes
      [JoinElement, PolymorphicJoinElement, StringElement]
    end

    def convert_options(options)
      result = {}
      case options
      when true,false
        result[:readonly] = options
      when Hash
        result = options
        if options[:migrate]
          result[:old_readonly] = options[:readonly]
          result[:readonly] = false
        end
      else
        raise RodException.new("Invalid options for open_database: #{options}!")
      end
      result[:readonly] = true if result[:readonly].nil?
      result
    end

    # Generates the classes for the data using the metadata from database.yml
    # +module_instance+ is the module in which the classes are generated.
    # This allows for embedding them in a separate namespace and use the same model
    # with different databases in the same time.
    def generate_classes(module_instance)
      special_names = special_classes.map{|k| k.name}
      special_names << "Rod"
      superclasses = {}
      @metadata.reject{|k,o| special_names.include?(k)}.each do |k,o|
        superclasses[k] = o[:superclass]
      end
      superclass_tree = {}
      superclasses.each do |klass,superclass|
        superclass_tree[klass] = []
        current_superclass = superclass
        loop do
          break if current_superclass.nil?
          superclass_tree[klass] << current_superclass
          break if current_superclass == "Rod::Model"
          current_superclass = superclasses[current_superclass]
        end
      end
      superclasses.keys.sort do |klass1,klass2|
        if superclass_tree[klass1].include?(klass2)
          1
        elsif superclass_tree[klass2].include?(klass1)
          -1
        else
          klass1 <=> klass2
        end
      end.each do |klass_name|
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
              if superclasses.keys.include?(options[:options][:class_name])
                metadata[property_type][property][:options][:class_name] =
                  prefix + options[:options][:class_name]
              end
            end
          end
          # klass name
          klass_name = prefix + klass_name
          @metadata.delete(original_name)
          @metadata[klass_name] = metadata
        end
        klass = Model.generate_class(klass_name,metadata)
        klass.model_path = Model.struct_name_for(original_name)
        @classes << klass
        klass.database_class(self.class)
      end
    end

    # During migration it creats the classes which are used to read
    # the legacy data. It also changes the path for the
    # actual classes not to conflict with paths of legacy data.
    def create_legacy_classes
      legacy_module = nil
      begin
        legacy_module = Object.const_get(LEGACY_MODULE)
      rescue NameError
        legacy_module = Module.new
        Object.const_set(LEGACY_MODULE,legacy_module)
      end
      self.classes.each do |klass|
        next if special_class?(klass)
        klass.model_path = Model.struct_name_for(klass.name) + NEW_DATA_SUFFIX
      end
      generate_classes(legacy_module)
    end


    # Writes the metadata to the database.yml file.
    def write_metadata
      metadata = {}
      rod_data = metadata["Rod"] = {}
      rod_data[:version] = VERSION
      rod_data[:created_at] = self.metadata["Rod"][:created_at] || Time.now
      rod_data[:updated_at] = Time.now
      self.classes.each do |klass|
        metadata[klass.name] = klass.metadata(self)
      end
      File.open(@path + DATABASE_FILE,"w") do |out|
        out.puts(YAML::dump(metadata))
      end
    end
  end
end

