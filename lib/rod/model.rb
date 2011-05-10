require File.join(File.dirname(__FILE__),'constants')

module Rod

  # Abstract class representing a model entity. Each storable class has to derieve from +Model+.
  class Model
    include ActiveModel::Validations

    # Method _initialize must not be called for abstract Model class.
    # This might happen if +build_structure+ was not called for the
    # class.
    def _initialize
      raise RodException.new("Ensure that the +build_structure+ call was sent to concreate classes.\n" +
                             "This won't happen if they are not linked with any database\n" +
                             "or the database was not created/opened.")
    end

    private :_initialize

    # Initializes instance of the model. If +struct+ is given,
    # it is used as source (C-level, i.e. Rod::Model::Struct)
    # of the data. Otherwise, a new struct is created.
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

    #########################################################################
    # Public API
    #########################################################################

    # Stores the instance in the database. This might be called
    # only if the database is opened for writing (see +create+).
    # To skip validation pass false.
    def store(validate=true)
      if validate
        if valid?
          self.class.store(self)
        else
          raise ValidationException.new([self.to_s,self.errors.full_messages])
        end
      else
        self.class.store(self)
      end
    end

    # Default implementation of equality.
    def ==(other)
      self.class == other.class && self.rod_id == other.rod_id
    end

    # Returns the number of objects of this class stored in the
    # database.
    def self.count
      self_count =
        if database.readonly_data?
          database.count(self)
        else
          @object_count || 0
        end
      # This should be changed if all other featurs connected with
      # inheritence are implemented, especially #14
      #subclasses.inject(self_count){|sum,sub| sum + sub.count}
      self_count
    end

    # Iterates over object of this class stored in the database.
    # The database must be opened for reading (see +open+).
    def self.each
      #TODO an exception if in wrong state?
      self.count.times do |index|
        yield self.get(index)
      end
    end

    # Returns n-th (+index+) object of this class stored in the database.
    # This call is scope-checked.
    def self.[](index)
      if index >= 0 && index < self.count
        get(index)
      else
        raise IndexError.new("The index is out of scope [0...#{self.count}]")
      end
    end

    protected
    # A macro-style function used to indicate that given piece of data
    # is stored in the database.
    # Type should be one of:
    # * +:integer+
    # * +:ulong+
    # * +:float+
    # * +:string+
    # Options:
    # * +:index+ if set to true, builds a simple hash index for the field
    # Warning!
    # rod_id is a predefined field
    def self.field(name, type, options={})
      ensure_valid_name(name)
      ensure_valid_type(type)
      self.fields[name] = options.merge({:type => type})
    end

    # A macro-style function used to indicate that instances of this
    # class are associated with many instances of some other class. The
    # name of the class is guessed from the field name, but you can
    # change it via options.
    # Options:
    # * +:class_name+ - the name of the class (as String) associated
    #   with this class
    def self.has_many(name, options={})
      ensure_valid_name(name)
      self.plural_associations[name] = options
    end

    # A macro-style function used to indicate that instances of this
    # class are associated with one instance of some other class. The
    # name of the class is guessed from the field name, but you can
    # change it via options.
    # Options:
    # * +:class_name+ - the name of the class (as String) associated
    #   with this class
    def self.has_one(name, options={})
      ensure_valid_name(name)
      self.singular_associations[name] = options
    end

    # A macro-style function used to link the model with specific
    # database class. See notes on Rod::Database for further
    # informations why this is needed.
    def self.database_class(klass)
      unless @database.nil?
        @database.remove_class(self)
      end
      @database = klass.instance
      self.add_to_database
    end

    #########################################################################
    # 'Private' API
    #########################################################################

    public
    # Set id of the object referenced via singular association.
    def set_referenced_id(name, value)
      sync_struct
      send("_#{name}=", @struct, value)
    end

    # Set id of the object referenced via plural association.
    #
    # The name of the association is +name+, the referenced
    # object id is +object_id+ and +index+ is the position
    # of the referenced object in the association.
    def set_element_referenced_id(name, object_id, index)
      sync_struct
      offset = send("_#{name}_offset",@struct)
      database.set_join_element_id(offset, index, object_id)
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
      Marshal.dump(@indices[field])
    end

    # Stores given +object+ in the database. The object must be an
    # instance of this class.
    def self.store(object)
      raise "Incompatible object class #{object.class}" unless object.is_a?(self)
      raise "The object #{object} is allready stored" unless object.rod_id == 0
      @indices ||= {}
      database.store(self,object)
      @object_count += 1
      # XXX a sort of 'memory leak' #19
      cache[object.rod_id-1] = object

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
      referenced_objects ||= database.referenced_objects
      # ... via singular associations
      singular_associations.each do |name, options|
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
      plural_associations.each do |name, options|
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
          referee = referee.class.find_by_rod_id(referee.rod_id)
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

    def self.find_by_rod_id(rod_id)
      raise "Requested id does not represent any object stored in the database!" unless rod_id != 0
      get(rod_id - 1)
    end

    # Returns the fields of this class.
    def self.fields
      if self == Rod::Model
        @fields ||= {"rod_id" => {:type => :ulong}}
      else
        @fields ||= superclass.fields.dup
      end
    end

    # Returns singular associations of this class.
    def self.singular_associations
      if self == Rod::Model
        @singular_associations ||= {}
      else
        @singular_associations ||= superclass.singular_associations.dup
      end
    end

    # Returns plural associations of this class.
    def self.plural_associations
      if self == Rod::Model
        @plural_associations ||= {}
      else
        @plural_associations ||= superclass.plural_associations.dup
      end
    end

    protected

    # Returns object of this class stored in the DB at given +position+.
    def self.get(position)
      object = cache[position]
      if object.nil?
        struct = database.get_structure(self,position)
        object = self.new(struct)
        cache[position] = object
      end
      object
    end

    # Used for establishing link with the DB.
    def self.inherited(subclass)
      begin
        subclass.add_to_database
        subclasses << subclass
      rescue MissingDatabase
        # this might happen for classes which inherit directly from
        # the Rod::Model. Since the +inherited+ method is always called
        # before the +database_class+ call, they never have the DB set-up
        # when this is called.
        # +add_to_database+ is called within +database_class+ for them.
      end
    end

    # Returns the subclasses of this class
    def self.subclasses
      @subclasses ||= []
      @subclasses
    end

    # Add self to the database it is linked to.
    def self.add_to_database
      self.database.add_class(self)
    end

    # Returns the database given instance belongs to (is or will be stored within).
    def database
      self.class.database
    end

    # Checks if the name of the field or association is valid.
    def self.ensure_valid_name(name)
      if name.to_s.empty? || INVALID_NAMES.has_key?(name)
        raise InvalidArgument.new(name,"field/association name")
      end
    end

    # Checks if the type of the field is valid.
    def self.ensure_valid_type(type)
      unless TYPE_MAPPING.has_key?(type)
        raise InvalidArgument.new(type,"field type")
      end
    end

    # Returns the database this class is linked to.
    # The database class is configured with the call to
    # macro-style function +database_class+. This information
    # is inherited, so it have to be defined only for the
    # root-class of the model (if such a class exists).
    def self.database
      return @database unless @database.nil?
      if self.superclass.respond_to?(:database)
        @database = self.superclass.database
      else
        raise MissingDatabase.new(self)
      end
      @database
    end

    # Synchronizes the structure held by the instance with the database
    # structure.
    def sync_struct
      unless @rod_id.nil?
        @struct = database.get_structure(self.class,@rod_id-1)
      end
    end

    # The object cache of this class.
    # XXX consider moving it to the database.
    def self.cache
      @cache ||= WeakHash.new
    end

    # The module context of the class.
    def self.module_context
      context = name[0...(name.rindex( '::' ) || 0)]
      context.empty? ? Object : eval(context)
    end

    # Returns the name of the scope of the class.
    def self.scope_name
      if self.module_context == Object
        ""
      else
        self.module_context.to_s
      end
    end

    #########################################################################
    # C-oriented API
    #########################################################################

    # The C structure representing this class.
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
              SUBEND
            end
          end.join("\n|  \n") }
          |  #{singular_associations.map do |name, options|
            "unsigned long #{name};"
          end.join("\n|  ")}
          |  \n#{plural_associations.map do |name, options|
         "|  unsigned long #{name}_offset;\n"+
         "|  unsigned long #{name}_count;"
          end.join("\n|  \n")}
          |} #{struct_name()};
      END
      result.margin
    end

    # Prints the memory layout of the structure.
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
          |  \n#{singular_associations.map do |name, options|
            "  printf(\"  singular assoc '#{name}': %lu\\n\",sizeof(unsigned long));"
          end.join("\n|  ")}
          |  \n#{plural_associations.map do |name, options|
         "|  printf(\"  plural assoc '#{name}' offset: %lu, count %lu\\n\",\n"+
         "|    sizeof(unsigned long),sizeof(unsigned long));"
          end.join("\n|  \n")}
      END
      result.margin
    end

    # Reads the value of a specified field of the C-structure.
    def self.field_reader(name,result_type,builder)
      str =<<-END
      |#{result_type} _#{name}(VALUE struct_value){
      |  #{struct_name()} * struct_p;
      |  Data_Get_Struct(struct_value,#{struct_name()},struct_p);
      |  return struct_p->#{name};
      |}
      END
      builder.c(str.margin)
    end

    # Writes the value of a specified field of the C-structure.
    def self.field_writer(name,arg_type,builder)
      str =<<-END
      |void _#{name}_equals(VALUE struct_value,#{arg_type} value){
      |  #{struct_name()} * struct_p;
      |  Data_Get_Struct(struct_value,#{struct_name()},struct_p);
      |  struct_p->#{name} = value;
      |}
      END
      builder.c(str.margin)
    end

    # Adds C routines and dynamic Ruby accessors for a model class.
    def self.build_structure
      @object_count = 0
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
            SUBEND
          end
        end.join("\n")}
        |  \n#{singular_associations.map do |name,options|
        <<-SUBEND
        |  result->#{name} = 0;
        SUBEND
        end.join("\n")}
        |  \n#{plural_associations.map do |name, options|
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

        if Database.development_mode
          # This method is created to force rebuild of the C code, since
          # it is rebuild on the basis of methods' signatures change.
          builder.c_singleton("void __unused_method_#{rand(1000)}(){}")
        end

        self.fields.each do |name, options|
          if options[:type] != :string
            field_reader(name,TYPE_MAPPING[options[:type]],builder)
            field_writer(name,TYPE_MAPPING[options[:type]],builder)
          else
            field_reader("#{name}_length","unsigned long",builder)
            field_reader("#{name}_offset","unsigned long",builder)
          end
        end

        singular_associations.each do |name, options|
          field_reader(name,"unsigned long",builder)
          field_writer(name,"unsigned long",builder)
        end

        plural_associations.each do |name, options|
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
          private "_#{field}_length".to_sym, "_#{field}_offset".to_sym
        end

        if options[:type] != :string
          # getter
          define_method(field) do
            value = instance_variable_get("@#{field}")
            if value.nil?
              value = send("_#{field}",@struct)
              instance_variable_set("@#{field}".to_sym,value)
            end
            value
          end

          # setter
          define_method("#{field}=") do |value|
            sync_struct
            send("_#{field}=",@struct,value)
            instance_variable_set("@#{field}".to_sym,value)
            value
          end
        else #strings
          # getter
          define_method(field) do
            value = instance_variable_get(("@" + field.to_s).to_sym)
            if value.nil? # first call
              length = send("_#{field}_length", @struct)
              offset = send("_#{field}_offset", @struct)
              value = database.read_string(length, offset)
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
                values = %w{length offset}.map do |type|
                    database.read_index(self,field,type)
                  end
                marshalled = database.read_string(*values)
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

      singular_associations.each do |name, options|
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

      plural_associations.each do |name, options|
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
            indices = database.join_indices(self.send("_#{name}_offset",@struct),count)
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
