require 'singleton'
module Rod
  # This class implements the database abstraction, i.e. it
  # is a mediator between some model (a set of classes) and
  # the generated C code, implementing the data storage functionality.
  #
  # Instance of the class should not be used *as* the database (i.e.
  # not in the macro-style function Rod::Model#database_class).
  # A user should strongly consider subclassing it, since refraining
  # from doing that, will not allow to use different databases for different
  # models simultaneously. This is due to the way RubyInline creates and
  # names (after the name of the class) the C code.
  class Database
    # This class is a singleton, since in a given time instant there
    # is only one database (one file/set of files) storing data of
    # a given model (set of classes).
    include Singleton

    # Initializes the classes linked with this database and the handler.
    def initialize
      @classes ||= [JoinElement, StringElement]
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
      @handler = exporter_class.create(path,self.classes)
    end

    # Opens the database at +path+ for readonly mode. This allows
    # for Rod::Model.count, Rod::Model.each, and similar calls.
    def open_database(path)
      raise "Database already opened." unless @handler.nil?
      @readonly = true
      self.classes.each{|s| s.send(:build_structure)}
      @handler = loader_class.open(path,self.classes)
    end

    # Closes the database.
    #
    # If the +purge_classes+ flag is set to true, the information about the classes
    # linked with this database is removed. This is important for testing, when
    # classes with same names have different definitions.
    def close_database(purge_classes=false)
      raise "Database not opened." if @handler.nil?

      if readonly_data?
        loader_class.close(@handler, nil)
      else
        unless referenced_objects.select{|k, v| not v.empty?}.size == 0
          raise "Not all associations have been stored: #{referenced_objects.size} objects"
        end
        exporter_class.close(@handler, self.classes)
      end
      @handler = nil
      # clear class information
      if purge_classes
        @classes = [JoinElement, StringElement]
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
      @classes << klass
    end

    # Returns the C structure with given index for given +klass+.
    def get_structure(klass,index)
      service_class.send("_#{klass.struct_name}_get", @handler,index)
    end

    # Returns +count+ number of join indices starting from +offset+.
    # These are the indices for has many association of one type for one instance.
    def join_indices(offset, count)
      service_class._join_indices(offset, count, @handler)
    end

    # Sets the +object_id+ of the join element with +offset+ and +index+.
    def set_join_element_id(offset,index,object_id)
      service_class._set_join_element_offset(offset, index, object_id, @handler)
    end

    # Returns the string of given +length+ starting at given +offset+.
    def read_string(length, offset)
      # TODO the encoding should be stored in the DB
      # or configured globally
      service_class._read_string(length, offset, @handler).force_encoding("utf-8")
    end

    # Returns the number of objects for given +klass+.
    def count(klass)
      service_class.send("_#{klass.struct_name}_count",@handler)
    end

    # Reads field of +type+ of index of +klass+ of +field+.
    # Note: The first field refers to the inner structure of the
    # index (lenght,offset); the second field referst to the field
    # in the class.
    def read_index(klass,field,type)
      service_class.send("_read_#{klass.struct_name()}_#{field}_index_#{type}",
                         @handler)
    end

    # Returns the exporter or loader class depending on the mode that db is open in.
    #
    # XXX marked for removal
    def service_class
      if readonly_data?
        loader_class
      else
        exporter_class
      end
    end

    # Store the object in the database.
    def store(klass,object)
      exporter_class.send("_store_" + klass.struct_name,object,@handler)
    end

    # Prints the layout of the pages in memory and other
    # internal data of the model.
    def print_layout
      raise "Database not opened." if @handler.nil?
      if readonly_data?
        loader_class.print_layout(@handler)
      else
        exporter_class.print_layout(@handler)
      end
    end

    # Prints the last error of system call.
    def print_system_error
      service_class._print_system_error
    end


    protected

    # Returns collected subclasses.
    def classes
      @classes.sort{|c1,c2| c1.to_s <=> c2.to_s}
    end

    # Returns the class which is used to export the data
    # into the database.
    #
    # If multiple models are used in one runtime, each one
    # should define its own exporter class, which simply
    # inherits for the Rod::Exporter class.
    #
    # XXX marked for removal
    def exporter_class
      Rod::Exporter
    end

    # Returns the class which is used to load the data
    # from the database.
    #
    # If multiple models are used in one runtime, each one
    # should define its own loader class, which simply
    # inherits for the Rod::Loader class.
    #
    # XXX marked for removal
    def loader_class
      Rod::Loader
    end

    private

    # The database handler (i.e. C struct which holds the data).
    def handler
      raise "Database is not opened for reading nor writing" if @handler.nil?
      @handler
    end
  end
end
