require File.join(File.dirname(__FILE__),'constants')

module Rod
  class Model
    def _initialize
      raise "Method _initialize should not be called for abstract Model class"
    end

    private :_initialize

    # Initializes instance of the model. If +struct+ is given,
    # it is used as source of the data. Otherwise, a new struct
    # is created.
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
      self.class.store(self)
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

    # Stores given +object+ in the database. The object must be an 
    # instance of this class.
    def self.store(object)
      raise "Incompatible object class #{object.class}" unless object.is_a?(self)
      exporter_class.send("_store_" + self.struct_name,object,self.superclass.handler)

      referenced_objects ||= self.superclass.referenced_objects 
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
      loader_class.send("_#{self.struct_name}_count",self.superclass.handler)
    end

    # Iterates over object of this class stored in the database. 
    # The database must be opened for reading (see +open+).
    def self.each 
      self.count.times do |index|
        yield self.get(index)
      end
    end

    # Returns object of this class stored in the DB at given +position+.
    def self.get(position)
      struct = loader_class.send("_#{self.struct_name}_get",
                                 self.superclass.handler,position)
      # TODO cache results
      self.new(struct)
    end

    # Returns the fields of this class.
    def self.fields
      @fields
    end

    # Returns singular associations of this class.
    def self.singular_associations
      @singular_associations
    end

    # Returns plural associations of this class.
    def self.plural_associations
      @plural_associations
    end

    # Creates the database at specified +path+, which allows 
    # for Model#store calls to be performed.
    #
    # By default the database is created for all subclasses.
    def self.create_database(path, joins_count)
      raise "Database already opened." unless @handler.nil?
      @readonly = false
      classes = {}
      if @subclasses
        @subclasses.each{|c| classes[c] = c.instances_count}
      end
      classes[JoinElement] = joins_count 
      @handler = exporter_class.create(path,classes)
    end

    # Opens the database at +path+ for reading. This allows
    # for Model#count, Model#each, and similar calls. 
    #
    # By default the database is opened for all subclasses.
    def self.open_database(path)
      raise "Database already opened." unless @handler.nil?
      @readonly = true
      classes = {}
      if @subclasses
        @subclasses.each{|c| classes[c] = 0}
      end
      classes[JoinElement] = 0 
      @handler = loader_class.open(path,classes)
    end

    def self.readonly_data
      @readonly
    end

    # Closes the database.
    def self.close_database
      raise "Database not opened." if @handler.nil?
      if @readonly
        loader_class.close(@handler)
      else
        exporter_class.close(@handler)
      end
      @handler = nil
    end
    
    # Explicitly sets the number of instances to be stored
    # in the database.
    def self.instances_count=(value)
      @instances_count = value
    end
    
    # Used for building the C code.
    def self.inherited(subclass)
      @subclasses ||= []
      @subclasses << subclass
    end

  protected
    # Returns the number of instances of this class
    # which are to be stored in the database.
    #
    # In most cases it should be set by call to +instances_count=+, since
    # the basic implementation count the number of objects in the object 
    # space.
    def self.instances_count
      if @instances_count
        @instances_count
      else
        ObjectSpace.each_object(self).to_a.size
      end
    end

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
    # TODO Check if empty on #close
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
    def self.field(name, type)
      # rod_id is a predefined field
      @fields ||= {"rod_id" => :ulong}
      @fields[name] = type
    end

    def self.has_many(name, options={})
      @plural_associations ||= {}
      @plural_associations[name] = options
    end

    def self.has_one(name, options={})
      @singular_associations ||= {}
      @singular_associations[name] = options
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
          |  #{@fields.map do |field,type| 
            "#{TYPE_MAPPING[type]} #{field};"
          end.join("\n|  ") }
          |  #{@singular_associations.map do |name, options|
            "unsigned long #{name};"
          end.join("\n|  ")}
          |  \n#{@plural_associations.map do |name, options|
         "|  unsigned long #{name}_offset;\n"+
         "|  unsigned long #{name}_count;"
          end.join("\n|  ")}
          |} #{struct_name()};
      END
      result.margin
    end

    def self.join_indices(offset, count)
      if self.superclass.readonly_data
        loader_class.
          _join_indices(offset, count, self.superclass.handler)
      else
        exporter_class.
          _join_indices(offset, count, self.superclass.handler)
      end
    end

    def self.build_structure
      @fields ||= {"rod_id" => :ulong}
      @plural_associations ||= {}
      @singular_associations ||= {}

      inline(:C) do |builder|
        builder.prefix(typedef_struct)

        str =<<-END
        |VALUE _initialize(){
        |  #{struct_name()} * result = ALLOC(#{struct_name()});
        |  result->rod_id = 0;
        |  VALUE cClass = rb_define_class("#{struct_class_name()}",rb_cObject);
        |  return Data_Wrap_Struct(cClass, 0, free, result);
        |}
        END
        builder.c(str.margin)

        @fields.each do |field_name, type|
          str =<<-END
          |VALUE _#{field_name}(VALUE struct_value){
          |#{struct_p}
          |  return #{C_TO_RUBY_MAPPING[type]}(struct_p->#{field_name});
          |}
          END
          builder.c(str.margin)
            
          str =<<-END
          |void _#{field_name}_equals(VALUE struct_value, VALUE value){
          |#{struct_p}
          |  struct_p->#{field_name} = #{RUBY_TO_C_MAPPING[type]}(value);
          |}
          END
          builder.c(str.margin)
        end

        @singular_associations.each do |name, options|
          str =<<-END
          |unsigned long _#{name}(VALUE struct_value){
          |#{struct_p}
          |  return struct_p->#{name};
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |void _#{name}_equals(VALUE struct_value, unsigned long value){
          |#{struct_p}
          |  struct_p->#{name} = value;
          |}
          END
          builder.c(str.margin)
        end

        @plural_associations.each do |name, options|
          str =<<-END
          |unsigned long _#{name}_count(VALUE struct_value){
          |#{struct_p}
          |  return struct_p->#{name}_count;
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |unsigned long _#{name}_offset(VALUE struct_value){
          |#{struct_p}
          |  return struct_p->#{name}_offset;
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |void _#{name}_count_equals(VALUE struct_value, unsigned long value){
          |#{struct_p}
          |  struct_p->#{name}_count = value;
          |}
          END
          builder.c(str.margin)

          str =<<-END
          |void _#{name}_offset_equals(VALUE struct_value, unsigned long value){
          |#{struct_p}
          |  struct_p->#{name}_count = value;
          |}
          END
          builder.c(str.margin)
        end
      end

      @fields.each do |field, type|
        private "_#{field}".to_sym, "_#{field}=".to_sym 

        define_method(field) do 
          send("_#{field}",@struct)
        end

        define_method("#{field}=") do |value|
          send("_#{field}=",@struct,value)
        end
      end

      @singular_associations.each do |name, options|
        class_name = 
          if options[:class_name]
            options[:class_name]
          else
            name.to_s.camelcase(true)
          end

        define_method(name) do
          value = instance_variable_get(("@" + name.to_s).to_sym)
          if value.nil?
            index = send("_#{name}",@struct)
            # the indices are shifted by 1, to leave 0 for nil
            if index == 0
              value = nil
            else
              value = constant("::" + class_name).get(index-1)
            end
            instance_variable_set(("@" + name.to_s).to_sym, value)
          end
          value
        end

        define_method("#{name}=") do |value|
          instance_variable_set(("@" + name.to_s).to_sym, value)
        end
      end

      @plural_associations.each do |name, options|
        class_name = 
          if options[:class_name]
            options[:class_name]
          else
            ::English::Inflect.singular(name.to_s).camelcase(true)
          end

        define_method("#{name}") do
          values = instance_variable_get(("@" + name.to_s).to_sym)
          klass = constant("::" + class_name)
          if values.nil?
            indices = self.class.
              join_indices(self.send("_#{name}_offset",@struct),
                           self.send("_#{name}_count",@struct))
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

        define_method("#{name}_count") do
          send("_#{name}_count",@struct)
        end

        define_method("#{name}=") do |value|
          instance_variable_set(("@" + name.to_s).to_sym, value)
        end
      end
    end
  end
end
