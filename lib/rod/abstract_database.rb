require 'singleton'
require 'yaml'

module Rod
  # This class implements the database abstraction, i.e. it
  # is a mediator between some model (a set of classes) and
  # the generated C code, implementing the data storage functionality.
  class AbstractDatabase
    # This class is a singleton, since in a given time instant there
    # is only one database (one file/set of files) storing data of
    # a given model (set of classes).
    include Singleton

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
        Dir.glob("#{@path}*").each do |file_name|
          File.delete(file_name) unless File.directory?(file_name)
        end
      else
        Dir.mkdir(@path)
      end
      generate_c_code(@path, classes)
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
      metadata = {}
      File.open(@path + DATABASE_FILE) do |input|
        metadata = YAML::load(input)
      end
      @handler = _init_handler(@path)
      self.classes.each do |klass|
        meta = metadata[klass.name]
        if meta.nil?
          # new class
          next
        end
        set_count(klass,meta[:count])
        file_size = File.new(klass.path_for_data(@path)).size
        unless file_size % _page_size == 0
          raise DatabaseError.new("Size of data file of #{klass} is invalid: #{file_size}")
        end
        set_page_count(klass,file_size / _page_size)
        klass.fields.each do |field,options|
          if options[:index]
            send("_#{klass.struct_name()}_#{field}_index_length_equals",
                 @handler, meta[:fields][field][:length])
            send("_#{klass.struct_name()}_#{field}_index_offset_equals",
                 @handler, meta[:fields][field][:offset])
          end
        end
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
        # write the indices first for the string elements to have proper count
        self.classes.each do |klass|
          meta = metadata[klass.name] = {}
          fields = meta[:fields] = {} unless klass.fields.empty?
          klass.fields.each do |field,options|
            fields[field] = {}
            fields[field][:options] = options
            if options[:index]
              length, offset = write_index(klass,field)
              fields[field][:length] = length
              fields[field][:offset] = offset
            end
          end
        end
        self.classes.each do |klass|
          meta = metadata[klass.name]
          meta[:count] = count(klass)
          meta[:page_count] = send("_#{klass.struct_name}_page_count",@handler)
          next if special_class?(klass)
          has_one = meta[:has_one] = {} unless klass.singular_associations.empty?
          klass.singular_associations.each do |name,options|
            has_one[name] = {}
            has_one[name][:options] = options
          end
          has_many = meta[:has_many] = {} unless klass.plural_associations.empty?
          klass.plural_associations.each do |name,options|
            has_many[name] = {}
            has_many[name][:options] = options
          end
        end
        File.open(@path + DATABASE_FILE,"w") do |out|
          out.puts(YAML::dump(metadata))
        end
      end
      _close(@handler)
      @handler = nil
      # clear class information
      if purge_classes
        @classes = self.class.special_classes
      end
    end

    # Clears the cache of the database.
    def clear_cache
      classes.each{|c| c.cache.cache.clear}
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

    # Returns the C structure with given index for given +klass+.
    def get_structure(klass,index)
      send("_#{klass.struct_name}_get", @handler,index)
    end

    # Returns +count+ number of join indices starting from +offset+.
    # These are the indices for has many association of one type for one instance.
    def join_indices(offset, count)
      _join_element_indices(offset, count, @handler)
    end

    # Returns +count+ number of polymorphic join indices starting from +offset+.
    # These are the indices for has many association of one type for one instance.
    # Each index is a pair of object index and object class id (classname_hash).
    def polymorphic_join_indices(offset, count)
      table = _polymorphic_join_element_indices(offset, count, @handler)
      if table.size % 2 != 0
        raise DatabaseError.new("Polymorphic join indices table is not even!")
      end
      (table.size/2).times.map{|i| [table[i*2],table[i*2+1]]}
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

    # Reads index of +field+ for +klass+.
    def read_index(klass,field)
      length = send("_#{klass.struct_name()}_#{field}_index_length", @handler)
      offset = send("_#{klass.struct_name()}_#{field}_index_offset", @handler)
      return {} if length == 0
      marshalled = _read_string(length,offset,@handler)
      Marshal.load(marshalled)
    end

    # Store index of +field+ of +klass+ in the database.
    def write_index(klass,field)
      raise DatabaseError.new("Readonly database.") if readonly_data?
      marshalled = Marshal.dump(klass.index_for(field))
      _set_string(marshalled,@handler)
    end

    # Store the object in the database.
    def store(klass,object)
      raise DatabaseError.new("Readonly database.") if readonly_data?
      send("_store_" + klass.struct_name,object,@handler)
      # set fields' values
      object.class.fields.each do |name,options|
        # rod_id is set during _store
        object.update_field(name) unless name == "rod_id"
      end
      # set ids of objects referenced via singular associations
      object.class.singular_associations.each do |name,options|
        object.update_singular_association(name,object.send(name),false)
      end
      # set ids of objects referenced via plural associations
      object.class.plural_associations.each do |name,options|
        elements = object.send(name) || []
        if options[:polymorphic]
          offset = _allocate_polymorphic_join_elements(elements.size,@handler)
        else
          offset = _allocate_join_elements(elements.size,@handler)
        end
        object.update_count_and_offset(name,elements.size,offset)
        elements.each.with_index do |associated,index|
          object.update_plural_association(name,associated,index,false)
        end
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
