require File.join(File.dirname(__FILE__),'constants')

module Rod

  # Abstract class representing a model entity. Each storable class has to derieve from +Model+.
  class Model
    include ActiveModel::Validations

    class ValidationException < Exception
      def initialize(message)
        @message = message
      end

      def to_s
        @message.join("\n")
      end
    end

    def _initialize
      raise "Method _initialize should not be called for abstract Model class"
    end

    private :_initialize

    # Initializes instance of the model. If +struct+ is given,
    # it is used as source of the data. Otherwise, a new struct
    # is created.
    #
    # NOTE that for a time being, this method should be considered FINAL.
    # You should not override it in any subclass.
    def initialize(struct=nil)
      if struct
        @struct = struct
      else
        @struct = _initialize()
      end
    end

    # Stores the instance in the database. This might be called
    # only if the database is openede for writing (see +create+).
    def store
      if valid?
        self.class.store(self)
      else
        raise ValidationException.new([self.to_s,self.errors.full_messages])
      end
    end

    def referenced_id(name)
      send("_#{name}", @struct)
    end

    # Set id of the object referenced via singular association
    def set_referenced_id(name, value)
      send("_#{name}=", @struct, value)
    end

    # Set id of the object referenced via plural association
    def set_element_referenced_id(name, value, index)
      offset = send("_#{name}_offset",@struct)
      self.class.set_element_referenced_id(offset, index, value)
    end

    # Set the referenced id of join element.
    def self.set_element_referenced_id(element_offset, 
                                       element_index, referenced_id)
      exporter_class.
        send("_set_join_element_offset", element_offset, 
             element_index, referenced_id, self.superclass.handler)
    end

    # Returns marshalled index for given field
    def self.field_index(field)
      if @indices.nil?
        raise "Indices not build for '#{self.name}'"
      end
      field = field.to_sym
      if @indices[field].nil?
        raise "Index for field '#{field}' not build in '#{self.name}'"
      end
      [Marshal.dump(@indices[field])].pack("m")
    end

    # Stores given +object+ in the database. The object must be an 
    # instance of this class.
    def self.store(object)
      raise "Incompatible object class #{object.class}" unless object.is_a?(self)
      raise "The object #{object} is allready stored" unless object.rod_id == 0
      @indices ||= {}
      exporter_class.send("_store_" + self.struct_name,object,self.superclass.handler)

      # update indices
      self.fields.each do |field,options|
        if options[:index]
          if @indices[field].nil?
            @indices[field] = {}
          end
          if @indices[field][object.send(field)].nil?
            # We don't use the hash default value approach,
            # since it forces the rebuild of the array
            @indices[field][object.send(field)] = []
          end
           @indices[field][object.send(field)] << object.rod_id
        end
      end

      # update object that references the stored object
      referenced_objects ||= self.superclass.referenced_objects 
      # ... via singular associations
      @singular_associations.each do |name, options|
        referenced = object.send(name)
        unless referenced.nil?
          # There is a referenced object, but its rod_id is not set.
          if referenced.rod_id == 0
            unless referenced_objects.has_key?(referenced)
              referenced_objects[referenced] = []
            end
            referenced_objects[referenced].push([object, name])
          end
        end
      end

      # ... via plural associations
      @plural_associations.each do |name, options|
        referenced = object.send(name)
        unless referenced.nil?
          referenced.each_with_index do |element, index|
            # There are referenced objects, but their rod_id is not set
            if element.rod_id == 0
              unless referenced_objects.has_key?(element)
                referenced_objects[element] = []
              end
              referenced_objects[element].push([object, name, index])
            end
          end
        end
      end

      reverse_references = referenced_objects.delete(object)

      unless reverse_references.blank?
        reverse_references.each do |referee, method_name, index|
          referee = referee.class.get(referee.rod_id-1)
          if index.nil?
            # singular association
            referee.set_referenced_id(method_name, object.rod_id)
          else
            referee.set_element_referenced_id(method_name, object.rod_id, index)
          end
        end
      end
    end

    # The name of the C struct for this class.
    def self.struct_name
      self.to_s.underscore.gsub(/\//,"__")
    end

    # The name of the struct class which is used to hold the C structs
    # wrapped into Ruby classes.
    def self.struct_class_name
      self.to_s+"::Struct"
    end

    # Returns the number of objects of this class stored in the 
    # database. The database must be opened for reading (see +open+).
    def self.count
      #TODO an exception if in wrong state?
      loader_class.send("_#{self.struct_name}_count",self.superclass.handler)
    end

    # Iterates over object of this class stored in the database. 
    # The database must be opened for reading (see +open+).
    def self.each 
      #TODO an exception if in wrong state?
      self.count.times do |index|
        yield self.get(index)
      end
    end

    # Returns object of this class stored in the DB at given +position+.
    def self.get(position)
      object = cache[position]
      if object.nil?
        struct = service_class.send("_#{self.struct_name}_get",
                                   self.superclass.handler,position)
        object = self.new(struct)
        cache[position] = object
      end
      object
    end

    def self.[](index)
      get(index)
    end

    def self.find_by_rod_id(rod_id)
      raise "Requested id does not represent any object stored in the database!" unless rod_id != 0
      get(rod_id - 1)
    end

    # Returns the fields of this class.
    def self.fields
      @fields ||= {"rod_id" => {:type => :ulong}}
    end

    # Returns singular associations of this class.
    def self.singular_associations
      @singular_associations
    end

    # Returns plural associations of this class.
    def self.plural_associations
      @plural_associations
    end

    # Returns whether db is opened.
    def self.opened?
      not @handler.nil?
    end

    # Creates the database at specified +path+, which allows 
    # for Model#store calls to be performed.
    #
    # By default the database is created for all subclasses.
    def self.create_database(path)
      raise "Database already opened." unless @handler.nil?
      @readonly = false
      self.subclasses.each{|s| s.send(:build_structure)}
      @handler = exporter_class.create(path,self.subclasses)
    end

    # Opens the database at +path+ for reading. This allows
    # for Model#count, Model#each, and similar calls. 
    #
    # By default the database is opened for all subclasses.
    def self.open_database(path)
      raise "Database already opened." unless @handler.nil?
      @readonly = true
      self.subclasses.each{|s| s.send(:build_structure)}
      @handler = loader_class.open(path,self.subclasses)
    end

    # Prints the layout of the pages in memory and other
    # internal data of the model.
    def self.print_layout
      raise "Database not opened." if @handler.nil?
      if @readonly
        loader_class.print_layout(@handler)
      else
        exporter_class.print_layout(@handler)
      end
    end

    # The DB open mode.
    def self.readonly_data?
      @readonly
    end

    # The array of pages on which this class's data is stored.
    def self.page_offsets
      @page_offsets ||= []
    end

    # Closes the database.
    def self.close_database
      raise "Database not opened." if @handler.nil?

      if @readonly
        loader_class.close(@handler, nil)
      else
        unless referenced_objects.select{|k, v| not v.empty?}.size == 0
          raise "Not all associations have been stored: #{referenced_objects}"
        end
        exporter_class.close(@handler, self.subclasses)
      end
      self.subclasses.each{|subc| subc.page_offsets.clear}
      @handler = nil
      @offsets = nil
    end

    # Returns collected subclasses.
    def self.subclasses
      @subclasses.sort{|c1,c2| c1.to_s <=> c2.to_s}
    end

    # Used for building the C code.
    def self.inherited(subclass)
      @subclasses ||= [JoinElement, StringElement]
      @subclasses << subclass
    end

    # Prints the last error of system call.
    def self.print_system_error
      service_class._print_system_error
    end

  protected
    # Returns the class which is used to export the data
    # in to the database.
    #
    # If multiple models are used in one runtime, each one
    # should define its own exporter class, which simply
    # inherits for the Rod::Exporter class.
    def self.exporter_class
      Rod::Exporter
    end

    # Returns the class which is used to load the data
    # from the database.
    #
    # If multiple models are used in one runtime, each one
    # should define its own loader class, which simply
    # inherits for the Rod::Loader class.
    def self.loader_class
      Rod::Loader
    end

    # The database handler (i.e. C struct which holds the data).
    def self.handler
      raise "Database is not opened for reading nor writing" if @handler.nil?
      @handler
    end

    # "Stack" of objects which are referenced by other objects during store, 
    # but are not yet stored.
    def self.referenced_objects
      @referenced_objects ||= {}
    end

    # A macro-styly function used to indicate that given piece of data
    # is stored in the database. 
    # Type should be one of:
    # * +:integer+
    # * +:ulong+
    # * +:float+
    # * +:string+
    def self.field(name, type, options={})
      # rod_id is a predefined field
      self.fields[name] = options.merge({:type => type})
    end

    def self.has_many(name, options={})
      @plural_associations ||= {}
      @plural_associations[name] = options
    end

    def self.has_one(name, options={})
      @singular_associations ||= {}
      @singular_associations[name] = options
    end

    def self.cache
      @cache ||= WeakHash.new
    end

    def self.clear_cache
      cache.cache.clear
    end

    def self.struct_p
      str =<<-END
      |  #{struct_name()} * struct_p;
      |  Data_Get_Struct(struct_value,#{struct_name()},struct_p);
      END
      str.margin
    end

    def self.typedef_struct
      result = <<-END
          |typedef struct {
          |  \n#{self.fields.map do |field,options| 
            if options[:type] != :string
              "|  #{TYPE_MAPPING[options[:type]]} #{field};"
            else
              <<-SUBEND
              |  unsigned long #{field}_length;
              |  unsigned long #{field}_offset;
              |  unsigned long #{field}_page;
              SUBEND
            end
          end.join("\n|  \n") }
          |  #{@singular_associations.map do |name, options|
            "unsigned long #{name};"
          end.join("\n|  ")}
          |  \n#{@plural_associations.map do |name, options|
         "|  unsigned long #{name}_offset;\n"+
         "|  unsigned long #{name}_count;"
          end.join("\n|  \n")}
          |} #{struct_name()};
      END
      result.margin
    end

    def self.layout
      result = <<-END
        |  \n#{self.fields.map do |field,options| 
            if options[:type] != :string
              "|  printf(\"  size of '#{field}': %lu\\n\",sizeof(#{TYPE_MAPPING[options[:type]]}));"
            else
              <<-SUBEND
              |  printf("  string '#{field}' length: %lu offset: %lu page: %lu\\n",
              |    sizeof(unsigned long), sizeof(unsigned long), sizeof(unsigned long));
              SUBEND
            end
          end.join("\n") }
          |  \n#{@singular_associations.map do |name, options|
            "  printf(\"  singular assoc '#{name}': %lu\\n\",sizeof(unsigned long));"
          end.join("\n|  ")}
          |  \n#{@plural_associations.map do |name, options|
         "|  printf(\"  plural assoc '#{name}' offset: %lu, count %lu\\n\",\n"+
         "|    sizeof(unsigned long),sizeof(unsigned long));"
          end.join("\n|  \n")}
      END
      result.margin
    end

    def self.field_reader(name,result_type,builder)
      str =<<-END
      |#{result_type} _#{name}(VALUE struct_value){
      |#{struct_p}
      |  return struct_p->#{name};
      |}
      END
      builder.c(str.margin)
    end

    def self.field_writer(name,arg_type,builder)
      str =<<-END
      |void _#{name}_equals(VALUE struct_value,#{arg_type} value){
      |#{struct_p}
      |  struct_p->#{name} = value;
      |}
      END
      builder.c(str.margin)
    end

    # Propagates the call to the underlying service class
    def self.join_indices(offset, count)
      service_class.
        _join_indices(offset, count, self.superclass.handler)
    end

    # Propagates the call to the underlying service class
    def self.read_string(length, offset, page)
      # TODO the encoding should be stored in the DB
      # or configured globally
      service_class._read_string(length, offset, page, self.superclass.handler).
        force_encoding("utf-8")
    end

    # Returns the exporter or loader class depending on the mode that db is open in
    def self.service_class
      if self.superclass.readonly_data?
        loader_class
      else
        exporter_class
      end
    end

    def self.modspace
      space = name[ 0...(name.rindex( '::' ) || 0)]
      space.empty? ? Object : eval(space)
    end
    
    # Returns a scope of the class
    def self.scope_name
      if self.modspace == Object
        ""
      else
        self.modspace.to_s
      end
    end

    # adds C routines and dynamic Ruby accessors for a model class
    def self.build_structure
      @plural_associations ||= {}
      @singular_associations ||= {}
      return if @structure_build

      inline(:C) do |builder|
        builder.prefix(typedef_struct)

        str =<<-END
        |VALUE _initialize(){
        |  #{struct_name()} * result = ALLOC(#{struct_name()});
        |  \n#{fields.map do |field, options|
          if options[:type] != :string
            <<-SUBEND
            |  result->#{field} = 0;
            SUBEND
          else
            <<-SUBEND
            |  result->#{field}_length = 0;
            |  result->#{field}_offset = 0;
            |  result->#{field}_page = 0;
            SUBEND
          end
        end.join("\n")}
        |  \n#{@singular_associations.map do |name,options|
        <<-SUBEND
        |  result->#{name} = 0;
        SUBEND
        end.join("\n")}
        |  \n#{@plural_associations.map do |name, options|
        <<-SUBEND
        |  result->#{name}_count = 0;
        |  result->#{name}_offset = 0;
        SUBEND
        end.join("\n")}
        |  VALUE cClass = rb_define_class("#{struct_class_name()}",rb_cObject);
        |  return Data_Wrap_Struct(cClass, 0, free, result);
        |}
        END
        builder.c(str.margin)

        self.fields.each do |name, options|
          if options[:type] != :string
            field_reader(name,TYPE_MAPPING[options[:type]],builder)
            field_writer(name,TYPE_MAPPING[options[:type]],builder)  
          else
            field_reader("#{name}_length","unsigned long",builder)
            field_reader("#{name}_offset","unsigned long",builder)
            field_reader("#{name}_page","unsigned long",builder)
          end
        end

        @singular_associations.each do |name, options|
          field_reader(name,"unsigned long",builder)
          field_writer(name,"unsigned long",builder)
        end

        @plural_associations.each do |name, options|
          field_reader("#{name}_count","unsigned long",builder)
          field_reader("#{name}_offset","unsigned long",builder)
          field_writer("#{name}_count","unsigned long",builder)
          field_writer("#{name}_offset","unsigned long",builder)
        end
      end

      ## accessors for fields, plural and singular relationships follow
      self.fields.each do |field, options|
        # adding new private fields visible from Ruby
        # they are lazily initialized based on the C representation
        if options[:type] != :string
          private "_#{field}".to_sym, "_#{field}=".to_sym 
        else
          private "_#{field}_length".to_sym, "_#{field}_offset".to_sym,
            "_#{field}_page".to_sym
        end

        if options[:type] != :string
          # getter
          define_method(field) do
            send("_#{field}",@struct)
          end
  
          # setter
          define_method("#{field}=") do |value|
            send("_#{field}=",@struct,value)
          end
        else #strings
          # getter
          define_method(field) do
            value = instance_variable_get(("@" + field.to_s).to_sym)
            if value.nil? # first call
              length = send("_#{field}_length", @struct)
              offset = send("_#{field}_offset", @struct)
              page = send("_#{field}_page", @struct)
              value = self.class.read_string(length, offset, page)
              # caching Ruby representation
              send("#{field}=",value)
            end
            value
          end

          # setter
          define_method("#{field}=") do |value|
            instance_variable_set("@#{field}".to_sym,value)
          end
        end

        if options[:index]
          (class << self; self; end).class_eval do
            define_method("find_all_by_#{field}".to_sym) do |value|
              index = instance_variable_get("@#{field}_index".to_sym)
              if index.nil?
                values = %w{length offset page}.map do |type|
                    service_class.
                      send("_read_#{struct_name}_#{field}_index_#{type}", 
                           superclass.handler)
                  end
                marshalled = self.read_string(*values).unpack("m").first
                index = Marshal.load(marshalled)
                instance_variable_set("@#{field}_index".to_sym,index)
              end
              (index[value] || []).map{|i| self.get(i-1)}
            end
          end

          #TODO could be more effective if didn't use find_all_by_field
          (class << self; self; end).class_eval do
            define_method("find_by_#{field}".to_sym) do |value|
              send("find_all_by_#{field}",value).first
            end
          end
        end
      end

      define_method(:rod_id) do
        instance_variable_get("@rod_id".to_sym) || 0
      end

      @singular_associations.each do |name, options|
        private "_#{name}".to_sym, "_#{name}=".to_sym
        class_name = 
          if options[:class_name]
            options[:class_name]
          else
            "#{self.scope_name}::#{name.to_s.camelcase}"
          end

        #getter
        define_method(name) do
          value = instance_variable_get(("@" + name.to_s).to_sym)
          if value.nil?
            index = send("_#{name}",@struct)
            # the indices are shifted by 1, to leave 0 for nil
            if index == 0
              value = nil
            else
              value = class_name.constantize.get(index-1)
            end
            send("#{name}=",value)
          end
          value
        end

        #setter
        define_method("#{name}=") do |value|
          instance_variable_set(("@" + name.to_s).to_sym, value)
        end
      end

      @plural_associations.each do |name, options|
        class_name = 
          if options[:class_name]
            options[:class_name]
          else
            "#{self.scope_name}::#{::English::Inflect.
              singular(name.to_s).camelcase}"
          end

        # getter
        define_method("#{name}") do
          values = instance_variable_get(("@" + name.to_s).to_sym)
          klass = class_name.constantize
          if values.nil?
            count = self.send("_#{name}_count",@struct)
            return instance_variable_set(("@" + name.to_s).to_sym,[]) if count == 0
            indices = self.class.
              join_indices(self.send("_#{name}_offset",@struct),count)
            # the indices are shifted by 1, to leave 0 for nil
            values = 
              indices.map do |index|
                if index == 0
                  nil
                else
                  klass.get(index-1)
                end
              end
            instance_variable_set(("@" + name.to_s).to_sym, values)
          end
          values
        end

        # count getter
        define_method("#{name}_count") do
          if (instance_variable_get(("@" + name.to_s).to_sym) != nil)
            return instance_variable_get(("@" + name.to_s).to_sym).count
          else
            return send("_#{name}_count",@struct)
          end
        end

        # setter
        define_method("#{name}=") do |value|
          instance_variable_set(("@" + name.to_s).to_sym, value)
        end
      end
      @structure_build = true
    end
  end
end
