require 'singleton'
require 'yaml'
require 'rod/segmented_index'

module Rod
  # This class implements the database abstraction, i.e. it
  # is a mediator between some model (a set of classes) and
  # the generated C code, implementing the data storage functionality.
  class AbstractDatabase
    # This class is a singleton, since in a given time instant there
    # is only one database (one file/set of files) storing data of
    # a given model (set of classes).
    include Singleton

    # The meta-data of the DataBase.
    attr_reader :metadata

    # Initializes the classes linked with this database and the handler.
    def initialize
      @classes ||= self.class.special_classes
      @handler = nil
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
      raise DatabaseError.new("Database already opened.") unless @handler.nil?
      @readonly = false
      self.classes.each{|s| s.send(:build_structure)}
      @path = canonicalize_path(path)
      # XXX maybe should be more careful?
      if File.exist?(@path)
        Dir.glob("#{@path}**/*").each do |file_name|
          File.delete(file_name) unless File.directory?(file_name)
        end
      else
        Dir.mkdir(@path)
      end
      generate_c_code(@path, classes)
      @metadata = {}
      @metadata["Rod"] = {}
      @metadata["Rod"][:created_at] = Time.now
      @handler = _init_handler(@path)
      _create(@handler)
    end

    # Opens the database at +path+ for readonly mode. This allows
    # for Rod::Model.count, Rod::Model.each, and similar calls.
    #
    # By default the database is opened in +readonly+ mode. You
    # can change it by passing +false+ as the second argument.
    def open_database(path,readonly=true)
      raise DatabaseError.new("Database already opened.") unless @handler.nil?
      @readonly = readonly
      self.classes.each{|s| s.send(:build_structure)}
      @path = canonicalize_path(path)
      generate_c_code(@path, classes)
      @metadata = {}
      File.open(@path + DATABASE_FILE) do |input|
        @metadata = YAML::load(input)
      end
      unless valid_version?(@metadata["Rod"][:version])
        raise IncompatibleVersion.new("Incompatible versions - library #{VERSION} vs. " +
                                      "file #{metatdata["Rod"][:version]}")
      end
      @handler = _init_handler(@path)
      self.classes.each do |klass|
        meta = @metadata[klass.name]
        if meta.nil?
          # new class
          next
        end
        unless klass.compatible?(meta,self)
          raise IncompatibleVersion.new("Definition of #{klass.name} in database " +
                                        "and runtime are different.")
        end
        set_count(klass,meta[:count])
        file_size = File.new(klass.path_for_data(@path)).size
        unless file_size % _page_size == 0
          raise DatabaseError.new("Size of data file of #{klass} is invalid: #{file_size}")
        end
        set_page_count(klass,file_size / _page_size)
      end
      _open(@handler)
    end

    # Closes the database.
    #
    # If the +purge_classes+ flag is set to true, the information about the classes
    # linked with this database is removed. This is important for testing, when
    # classes with same names have different definitions.
    def close_database(purge_classes=false)
      raise DatabaseError.new("Database not opened.") if @handler.nil?

      unless readonly_data?
        unless referenced_objects.select{|k, v| not v.empty?}.size == 0
          raise DatabaseError.new("Not all associations have been stored: #{referenced_objects.size} objects")
        end
        metadata = {}
        rod_data = metadata["Rod"] = {}
        rod_data[:version] = VERSION
        rod_data[:created_at] = self.metadata["Rod"][:created_at]
        rod_data[:updated_at] = Time.now
        self.classes.each do |klass|
          metadata[klass.name] = klass.metadata(self)
          klass.indexed_properties.each do |property,options|
            write_index(klass,property,options)
          end
        end
        File.open(@path + DATABASE_FILE,"w") do |out|
          out.puts(YAML::dump(metadata))
        end
      end
      _close(@handler)
      @handler = nil
      # clear cached data
      self.clear_cache
      if purge_classes
        @classes = self.class.special_classes
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

    # Returns the string of given +length+ starting at given +offset+.
    def read_string(length, offset)
      # TODO the encoding should be stored in the DB
      # or configured globally
      _read_string(length, offset, @handler).force_encoding("utf-8")
    end

    # Stores the string in the DB encoding it to utf-8.
    def set_string(value)
      raise DatabaseError.new("Readonly database.") if readonly_data?
      _set_string(value.encode("utf-8"),@handler)
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

    # Reads index of +field+ (with +options+) for +klass+.
    def read_index(klass,field,options)
      case options[:index]
      when :flat,true
        begin
          File.open(klass.path_for_index(@path,field,options)) do |input|
            return {} if input.size == 0
            return Marshal.load(input)
          end
        rescue Errno::ENOENT
          return {}
        end
      when :segmented
        return SegmentedIndex.new(klass.path_for_index(@path,field,options))
      else
        raise RodException.new("Invalid index type '#{options[:index]}'.")
      end
    end

    # Store index of +field+ (with +options+) of +klass+ in the database.
    # There are two types of indices:
    # * +:flat+ - marshalled index is stored in one file
    # * +:segmented+ - marshalled index is stored in many files
    def write_index(klass,property,options)
      raise DatabaseError.new("Readonly database.") if readonly_data?
      class_index = klass.index_for(property,options)
      # Only rewrite the index, without (re)storing the values.
      unless options[:rewrite]
        class_index.each do |key,ids|
          unless ids.is_a?(CollectionProxy)
            proxy = CollectionProxy.new(ids[1],self,ids[0],klass)
          else
            proxy = ids
          end
          offset = _allocate_join_elements(proxy.size,@handler)
          proxy.each_id.with_index do |rod_id,index|
            set_join_element_id(offset, index, rod_id)
          end
          class_index[key] = [offset,proxy.size]
        end
      end
      case options[:index]
      when :flat,true
        File.open(klass.path_for_index(@path,property,options),"w") do |out|
          out.puts(Marshal.dump(class_index))
        end
      when :segmented
        path = klass.path_for_index(@path,property,options)
        if class_index.is_a?(Hash)
          index = SegmentedIndex.new(path)
          class_index.each{|k,v| index[k] = v}
        else
          index = class_index
        end
        index.save
        index = nil
      else
        raise RodException.new("Invalid index type '#{options[:index]}'.")
      end
    end

    # Store the object in the database.
    def store(klass,object)
      raise DatabaseError.new("Readonly database.") if readonly_data?
      new_object = (object.rod_id == 0)
      if new_object
        send("_store_" + klass.struct_name,object,@handler)
        # set fields' values
        object.class.fields.each do |name,options|
          # rod_id is set during _store
          object.update_field(name) unless name == "rod_id"
        end
        # set ids of objects referenced via singular associations
        object.class.singular_associations.each do |name,options|
          object.update_singular_association(name,object.send(name))
        end
      end
      # set ids of objects referenced via plural associations
      # TODO should be disabled, when there are no new elements
      object.class.plural_associations.each do |name,options|
        elements = object.send(name) || []
        if options[:polymorphic]
          offset = _allocate_polymorphic_join_elements(elements.size,@handler)
        else
          offset = _allocate_join_elements(elements.size,@handler)
        end
        object.update_count_and_offset(name,elements.size,offset)
        object.update_plural_association(name,elements)
      end
    end

    # Prints the layout of the pages in memory and other
    # internal data of the model.
    def print_layout
      raise DatabaseError.new("Database not opened.") if @handler.nil?
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
      path + "/" unless path[-1] == "/"
    end

    # Special classes used by the database.
    def self.special_classes
      [JoinElement, PolymorphicJoinElement, StringElement]
    end
  end
end
