require 'singleton'
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
    def create_database(path)
      raise "Database already opened." unless @handler.nil?
      @readonly = false
      self.classes.each{|s| s.send(:build_structure)}
      generate_c_code(path, classes)
      @handler = _create(path)
    end

    # Opens the database at +path+ for readonly mode. This allows
    # for Rod::Model.count, Rod::Model.each, and similar calls.
    def open_database(path)
      raise "Database already opened." unless @handler.nil?
      @readonly = true
      self.classes.each{|s| s.send(:build_structure)}
      generate_c_code(path, classes)
      @handler = _open(path)
    end

    # Closes the database.
    #
    # If the +purge_classes+ flag is set to true, the information about the classes
    # linked with this database is removed. This is important for testing, when
    # classes with same names have different definitions.
    def close_database(purge_classes=false)
      raise "Database not opened." if @handler.nil?

      if readonly_data?
        _close(@handler, nil)
      else
        unless referenced_objects.select{|k, v| not v.empty?}.size == 0
          raise "Not all associations have been stored: #{referenced_objects.size} objects"
        end
        _close(@handler, self.classes)
      end
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
      _join_indices(offset, count, @handler)
    end

    # Returns +count+ number of polymorphic join indices starting from +offset+.
    # These are the indices for has many association of one type for one instance.
    # Each index is a pair of object index and object class id (classname_hash).
    def polymorphic_join_indices(offset, count)
      table = _polymorphic_join_indices(offset, count, @handler)
      if table.size % 2 != 0
        raise RodException.new("Polymorphic join indices table is not even!")
      end
      (table.size/2).times.map{|i| [table[i*2],table[i*2+1]]}
    end

    # Sets the +object_id+ of the join element with +offset+ and +index+.
    def set_join_element_id(offset,index,object_id)
      _set_join_element_offset(offset, index, object_id, @handler)
    end

    # Sets the +object_id+ and +class_id+ of the
    # polymorphic join element with +offset+ and +index+.
    def set_polymorphic_join_element_id(offset,index,object_id,class_id)
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
      _set_string(value.encode("utf-8"),@handler)
    end

    # Returns the number of objects for given +klass+.
    def count(klass)
      send("_#{klass.struct_name}_count",@handler)
    end

    # Reads field of +type+ of index of +klass+ of +field+.
    # Note: The first field refers to the inner structure of the
    # index (lenght,offset); the second field referst to the field
    # in the class.
    def read_index(klass,field,type)
      send("_read_#{klass.struct_name()}_#{field}_index_#{type}",
           @handler)
    end

    # Store the object in the database.
    def store(klass,object)
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
      raise "Database not opened." if @handler.nil?
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

    # Special classes used by the database.
    def self.special_classes
      [JoinElement, PolymorphicJoinElement, StringElement]
    end
  end
end
