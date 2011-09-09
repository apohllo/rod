require 'rod/constants'
require 'rod/collection_proxy'
require 'rod/abstract_model'

module Rod

  # Abstract class representing a model entity. Each storable class has to derieve from +Model+.
  class Model < AbstractModel
    include ActiveModel::Validations
    include ActiveModel::Dirty
    extend Enumerable

    # A list of updaters that has to be notified when the +rod_id+
    # of this object is defined. See ReferenceUpdater for details.
    attr_reader :reference_updaters

    # If +options+ is an integer it is the @rod_id of the object.
    def initialize(options=nil)
      @reference_updaters = []
      case options
      when Integer
        @rod_id = options
      when Hash
        @rod_id = 0
        initialize_fields
        options.each do |key,value|
          begin
            self.send("#{key}=",value)
          rescue NoMethodError
            raise RodException.new("There is no field or association with name #{key}!")
          end
        end
      when NilClass
        @rod_id = 0
        initialize_fields
      else
        raise InvalidArgument.new("initialize(options)",options)
      end
    end

    # Returns duplicated object, which shares the state of fields and
    # associations, but is separatly persisted (has its own +rod_id+,
    # dirty attributes, etc.).
    # WARNING: This behaviour might change slightly in future #157
    def dup
      object = super()
      object.instance_variable_set("@rod_id",0)
      object.instance_variable_set("@reference_updaters",@reference_updaters.dup)
      object.instance_variable_set("@changed_attributes",@changed_attributes.dup)
      object
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
      # The default values doesn't have to be persisted, since they
      # are returned by default by the accessors.
      self.changed.each do |property|
        property = property.to_sym
        if self.class.field?(property)
          # store field value
          update_field(property)
        elsif self.class.singular_association?(property)
          # store singular association value
          update_singular_association(property,send(property))
        else
          # Plural associations are not tracked.
          raise RodException.new("Invalid changed property #{self.class}##{property}'")
        end
      end
      # store plural associations in the DB
      self.class.plural_associations.each do |property,options|
        collection = send(property)
        offset = collection.save
        update_count_and_offset(property,collection.size,offset)
      end
      # notify reference updaters
      reference_updaters.each do |updater|
        updater.update(self)
      end
      reference_updaters.clear
      # XXX we don't use the 'previously changed' feature, since the simplest
      # implementation requires us to leave references to objects, which
      # forbids them to be garbage collected.
      @changed_attributes.clear unless @changed_attributes.nil?
    end

    # Default implementation of equality.
    def ==(other)
      self.class == other.class && self.rod_id == other.rod_id
    end

    # Returns +true+ if the object hasn't been persisted yet.
    def new?
      @rod_id == 0
    end

    # Default implementation of +inspect+.
    def inspect
      fields = self.class.fields.map{|n,o| "#{n}:#{self.send(n)}"}.join(",")
      singular = self.class.singular_associations.map{|n,o| "#{n}:#{self.send(n).class}"}.join(",")
      plural = self.class.plural_associations.map{|n,o| "#{n}:#{self.send(n).size}"}.join(",")
      "#{self.class}:<#{fields}><#{singular}><#{plural}>"
    end

    # Default implementation of +to_s+.
    def to_s
      self.inspect
    end

    # Returns a hash {'attr_name' => 'attr_value'} which covers fields and
    # has_one relationships values. This is required by ActiveModel::Dirty.
    def attributes
      result = {}
      self.class.fields.each do |name,options|
        result[name.to_s] = self.send(name)
      end
      self.class.singular_associations.each do |name,options|
        result[name.to_s] = self.send(name)
      end
      result
    end

    # Returns the number of objects of this class stored in the
    # database.
    def self.count
      self_count = database.count(self)
      # This should be changed if all other featurs connected with
      # inheritence are implemented, especially #14
      #subclasses.inject(self_count){|sum,sub| sum + sub.count}
      self_count
    end

    # Iterates over object of this class stored in the database.
    def self.each
      #TODO an exception if in wrong state?
      if block_given?
        self.count.times do |index|
          yield get(index+1)
        end
      else
        enum_for(:each)
      end
    end

    # Returns n-th (+index+) object of this class stored in the database.
    # This call is scope-checked.
    def self.[](index)
      if index >= 0 && index < self.count
        get(index+1)
      else
        raise IndexError.
          new("The index #{index} is out of the scope [0...#{self.count}] for #{self}")
      end
    end

    protected
    # Sets the default values for fields.
    def initialize_fields
      self.class.fields.each do |name,options|
        next if name == "rod_id"
        value =
          case options[:type]
          when :integer
            0
          when :ulong
            0
          when :float
            0.0
          when :string
            ''
          when :object
            nil
          else
            raise InvalidArgument.new(options[:type],"field type")
          end
        send("#{name}=",value)
      end
    end

    # A macro-style function used to indicate that given piece of data
    # is stored in the database.
    # Type should be one of:
    # * +:integer+
    # * +:ulong+
    # * +:float+
    # * +:string+
    # * +:object+ (value is marshaled durign storage, and unmarshaled during read)
    # Options:
    # * +:index+ builds an index for the field and might be:
    # ** +:flat+ simple hash index (+true+ works as well for backwards compatiblity)
    # ** +:segmented+ index split for 1001 pieces for shorter load times (only
    #   one piece is loaded on one look-up)
    #
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
    # * +:polymorphic+ - if set to +true+ the association is polymorphic (allows to acess
    #   objects of different classes via this association)
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
    # * +:polymorphic+ - if set to +true+ the association is polymorphic (allows to acess
    #   objects of different classes via this association)
    def self.has_one(name, options={})
      ensure_valid_name(name)
      self.singular_associations[name] = options
    end

    # A macro-style function used to link the model with specific
    # database class. See notes on Rod::Database for further
    # information why this is needed.
    def self.database_class(klass)
      unless @database.nil?
        @database.remove_class(self)
      end
      @database = klass.instance
      self.add_to_database
    end

    #########################################################################
    # 'Private' instance methods
    #########################################################################

    public
    # Update the DB information about the +object+ which
    # is referenced via singular association with +name+.
    # If the object is not yet stored, a reference updater
    # is registered to update the DB when it is stored.
    def update_singular_association(name, object)
      if object.nil?
        rod_id = 0
      else
        if object.new?
          # There is a referenced object, but its rod_id is not set.
          object.reference_updaters << ReferenceUpdater.
            for_singular(self,name,self.database)
          return
        else
          rod_id = object.rod_id
        end
        # clear references, allowing for garbage collection
        # WARNING: don't use writer, since we don't want this change to be tracked
        #object.instance_variable_set("@#{name}",nil)
      end
      send("_#{name}=", @rod_id, rod_id)
      if self.class.singular_associations[name][:polymorphic]
        class_id = object.nil? ? 0 : object.class.name_hash
        send("_#{name}__class=", @rod_id, class_id)
      end
    end

    # Updates in the DB the +count+ and +offset+ of elements for +name+ association.
    def update_count_and_offset(name,count,offset)
      send("_#{name}_count=",@rod_id,count)
      send("_#{name}_offset=",@rod_id,offset)
    end

    # Updates in the DB the field +name+ to the actual value.
    def update_field(name)
      if self.class.string_field?(self.class.fields[name][:type])
        if self.class.fields[name][:type] == :string
          value = send(name)
        elsif self.class.fields[name][:type] == :object
          value = instance_variable_get("@#{name}")
          value = Marshal.dump(value)
        else
          raise RodException.new("Unrecognised field type '#{self.class.fields[name][:type]}'!")
        end
        options = {}
        if self.class.fields[name][:type] == :object
          options[:skip_encoding] = true
        end
        length, offset = database.set_string(value,options)
        send("_#{name}_length=",@rod_id,length)
        send("_#{name}_offset=",@rod_id,offset)
      else
        send("_#{name}=",@rod_id,send(name))
      end
    end

    #########################################################################
    # 'Private' class methods
    #########################################################################

    # Stores given +object+ in the database. The object must be an
    # instance of this class.
    def self.store(object)
      unless object.is_a?(self)
        raise RodException.new("Incompatible object class #{object.class}.")
      end
      stored_now = object.new?
      database.store(self,object)
      cache[object.rod_id] = object

      # update class indices
      indexed_properties.each do |property,options|
        # WARNING: singular and plural associations with nil as value are not indexed!
        # TODO #156 think over this constraint, write specs in persistence.feature
        if field?(property) || singular_association?(property)
          if stored_now || object.changes.has_key?(property)
            unless stored_now
              old_value = object.changes[property][0]
              self.index_for(property,options)[old_value].delete(object)
            end
            new_value = object.send(property)
            if field?(property) || new_value
              self.index_for(property,options)[new_value] << object
            end
          end
        elsif plural_association?(property)
          object.send(property).deleted.each do |deleted|
            self.index_for(property,options)[deleted].delete(object) unless deleted.nil?
          end
          object.send(property).added.each do |added|
            self.index_for(property,options)[added] << object unless added.nil?
          end
        else
          raise RodException.new("Unknown property type for #{self}##{property}")
        end
      end
    end

    # The name of the C struct for this class.
    def self.struct_name
      return @struct_name unless @struct_name.nil?
      name = struct_name_for(self.to_s)
      unless name =~ /^\#/
        # not an anonymous class
        @struct_name = name
      end
      name
    end

    # Returns the struct name for the class +name+.
    def self.struct_name_for(name)
      name.underscore.gsub(/\//,"__")
    end

    # Finder for rod_id.
    def self.find_by_rod_id(rod_id)
      if rod_id <= 0 || rod_id > self.count
        return nil
      end
      get(rod_id)
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

    # Metadata for the model class.
    def self.metadata
      meta = super
      # fields
      fields = meta[:fields] = {} unless self.fields.size == 1
      self.fields.each do |field,options|
        next if field == "rod_id"
        fields[field] = {}
        fields[field][:options] = options
      end
      # singular_associations
      has_one = meta[:has_one] = {} unless self.singular_associations.empty?
      self.singular_associations.each do |name,options|
        has_one[name] = {}
        has_one[name][:options] = options
      end
      # plural_associations
      has_many = meta[:has_many] = {} unless self.plural_associations.empty?
      self.plural_associations.each do |name,options|
        has_many[name] = {}
        has_many[name][:options] = options
      end
      meta
    end

    # Generates the model class based on the metadata and places
    # it in the +module_instance+ or Object (default scope) if module is nil.
    def self.generate_class(class_name,metadata)
      superclass = metadata[:superclass].constantize
      namespace = define_context(class_name)
      klass = Class.new(superclass)
      namespace.const_set(class_name.split("::")[-1],klass)
      [:fields,:has_one,:has_many].each do |type|
        (metadata[type] || []).each do |name,options|
          if type == :fields
            internal_options = options[:options].dup
            field_type = internal_options.delete(:type)
            klass.send(:field,name,field_type,internal_options)
          else
            klass.send(type,name,options[:options])
          end
        end
      end
      klass
    end

    # Migrates the class to the new model, i.e. it copies all the
    # values of properties that both belong to the class in the old
    # and the new model.
    def self.migrate
      new_class = self.name.sub(LEGACY_RE,"").constantize
      old_object = self.new
      new_object = new_class.new
      puts "Migrating #{new_class}" if $ROD_DEBUG
      self.properties.each do |name,options|
        next unless new_class.properties.keys.include?(name)
        print "-  #{name}... " if $ROD_DEBUG
        if options.map{|k,v| [k,v.to_s.sub(LEGACY_RE,"")]} !=
          new_class.properties[name].map{|k,v| [k,v.to_s]}
          raise IncompatibleVersion.
            new("Incompatible definition of property '#{name}'\n" +
                "Definition is different in the old and "+
                "the new schema for '#{new_class}':\n" +
                "  #{options} \n" +
                "  #{new_class.properties[name]}")
        end
        if self.field?(name)
          if self.string_field?(options[:type])
            self.count.times do |position|
              new_object.send("_#{name}_length=",position+1,
                              old_object.send("_#{name}_length",position+1))
              new_object.send("_#{name}_offset=",position+1,
                              old_object.send("_#{name}_offset",position+1))
            end
          else
            self.count.times do |position|
              new_object.send("_#{name}=",position + 1,
                              old_object.send("_#{name}",position + 1))
            end
          end
        elsif self.singular_association?(name)
          self.count.times do |position|
            new_object.send("_#{name}=",position + 1,
                            old_object.send("_#{name}",position + 1))
          end
          if options[:polymorphic]
            self.count.times do |position|
              new_object.send("_#{name}__class=",position + 1,
                              old_object.send("_#{name}__class",position + 1))
            end
          end
        else
          self.count.times do |position|
            new_object.send("_#{name}_count=",position + 1,
                            old_object.send("_#{name}_count",position + 1))
            new_object.send("_#{name}_offset=",position + 1,
                            old_object.send("_#{name}_offset",position + 1))
          end
        end
        puts "done" if $ROD_DEBUG
      end
    end

    protected
    # The pointer to the mmaped table of C structs.
    def self.rod_pointer
      @rod_pointer
    end

    # Writer for the pointer to the mmaped table of C structs.
    def self.rod_pointer=(value)
      @rod_pointer = value
    end

    # Used for establishing link with the DB.
    def self.inherited(subclass)
      super
      subclass.add_to_class_space
      subclasses << subclass
      begin
        subclass.add_to_database
      rescue MissingDatabase
        # This might happen for classes which inherit directly from
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

    # Add self to the Rod model class space. This is need
    # to determine the class for polymorphic associations.
    def self.add_to_class_space
      Model.add_class(self)
    end

    # Adds given +klass+ to the class space.
    # This method is used only for Model class itself. It should
    # not be called for the subclasses.
    def self.add_class(klass)
      raise RodException.new("'add_class' method is final for Rod::Model") if self != Model
      @class_space ||= {}
      @class_space[klass.name_hash] = klass
    end

    def self.get_class(klass_hash)
      raise RodException.new("'get_class' method is final for Rod::Model") if self != Model
      @class_space ||= {}
      klass = @class_space[klass_hash]
      if klass.nil?
        raise RodException.new("There is no class with name hash '#{klass_hash}'!\n" +
                              "Check if all needed classes are loaded.")
      end
      klass
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

    # The object cache of this class.
    # XXX consider moving it to the database.
    def self.cache
      @cache ||= Cache.new
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

    # Defines the namespace (contex) for given +class_name+ - if the constants
    # (modules and classes) are defined, they are just digged into,
    # if not - they are defined as modules.
    def self.define_context(class_name)
      class_name.split("::")[0..-2].inject(Object) do |mod,segment|
        begin
          mod.const_get(segment,false)
        rescue NameError
          new_mod = Module.new
          mod.const_set(segment,new_mod)
          new_mod
        end
      end
    end


    #########################################################################
    # DB-oriented API
    #########################################################################

    # The SHA2 digest of the class name
    #
    # Warning: if you dynamically create classes (via Class.new)
    # this value is random, until the class is bound with a constant!
    def self.name_hash
      return @name_hash unless @name_hash.nil?
      # This is not used to protect any value, only to
      # distinguish names of classes. It doesn't have to be
      # very strong agains collision attacks.
      @name_hash = Digest::SHA2.new.hexdigest(self.struct_name).
        to_s.to_i(16) % 2 ** 32
    end

    # Allows for setting arbitrary name for the model path, i.e.
    # the model-specific fragment of the path to the model files.
    # By default it is the same as Model.struct_name
    def self.model_path=(path)
      @model_path = path
    end

    # Returns the model path, i.e. the model-specific fragment of
    # the path to the model files (data, indices, etc.).
    def self.model_path
      @model_path || self.struct_name
    end

    # The name of the file (for given +relative_path+), which the data of this class
    # is stored in.
    def self.path_for_data(relative_path)
      "#{relative_path}#{model_path}.dat"
    end

    # The name of the file or directory (for given +relative_path+), which the
    # index of the +field+ of this class is stored in.
    def self.path_for_index(relative_path,field)
      "#{relative_path}#{model_path}_#{field}"
    end

    # Returns true if the type of the filed is string-like (i.e. stored as
    # StringElement).
    def self.string_field?(type)
      string_types.include?(type)
    end

    # Types which are stored as strings.
    def self.string_types
      [:string, :object]
    end

    # The C structure representing this class.
    def self.typedef_struct
      result = <<-END
      |typedef struct {
      |  \n#{self.fields.map do |field,options|
        unless string_field?(options[:type])
          "|  #{TYPE_MAPPING[options[:type]]} #{field};"
        else
          <<-SUBEND
          |  unsigned long #{field}_length;
          |  unsigned long #{field}_offset;
          SUBEND
        end
      end.join("\n|  \n") }
      |  #{singular_associations.map do |name, options|
        result = "unsigned long #{name};"
        if options[:polymorphic]
          result += "  unsigned long #{name}__class;"
        end
        result
      end.join("\n|  ")}
      |  \n#{plural_associations.map do |name, options|
        result =
          "|  unsigned long #{name}_offset;\n"+
          "|  unsigned long #{name}_count;"
        result
      end.join("\n|  \n")}
      |} #{struct_name()};
      END
      result.margin
    end

    # Prints the memory layout of the structure.
    def self.layout
      result = <<-END
      |  \n#{self.fields.map do |field,options|
          unless string_field?(options[:type])
            "|  printf(\"  size of '#{field}': %lu\\n\"," +
              "(unsigned long)sizeof(#{TYPE_MAPPING[options[:type]]}));"
          else
            <<-SUBEND
            |  printf("  string '#{field}' length: %lu offset: %lu page: %lu\\n",
            |    (unsigned long)sizeof(unsigned long), (unsigned long)sizeof(unsigned long),
            |    (unsigned long)sizeof(unsigned long));
            SUBEND
          end
        end.join("\n") }
        |  \n#{singular_associations.map do |name, options|
          "  printf(\"  singular assoc '#{name}': %lu\\n\","+
          "(unsigned long)sizeof(unsigned long));"
        end.join("\n|  ")}
        |  \n#{plural_associations.map do |name, options|
       "|  printf(\"  plural assoc '#{name}' offset: %lu, count %lu\\n\",\n"+
       "|    (unsigned long)sizeof(unsigned long),(unsigned long)sizeof(unsigned long));"
        end.join("\n|  \n")}
      END
      result.margin
    end

    # Reads the value of a specified field of the C-structure.
    def self.field_reader(name,result_type,builder)
      str =<<-END
      |#{result_type} _#{name}(unsigned long object_rod_id){
      |  if(object_rod_id == 0){
      |    rb_raise(rodException(), "Invalid object rod_id (0)");
      |  }
      |  VALUE klass = rb_funcall(self,rb_intern("class"),0);
      |  #{struct_name} * pointer = (#{struct_name} *)
      |    NUM2ULONG(rb_funcall(klass,rb_intern("rod_pointer"),0));
      |  return (pointer + object_rod_id - 1)->#{name};
      |}
      END
      builder.c(str.margin)
    end

    # Writes the value of a specified field of the C-structure.
    def self.field_writer(name,arg_type,builder)
      str =<<-END
      |void _#{name}_equals(unsigned long object_rod_id,#{arg_type} value){
      |  if(object_rod_id == 0){
      |    rb_raise(rodException(), "Invalid object rod_id (0)");
      |  }
      |  VALUE klass = rb_funcall(self,rb_intern("class"),0);
      |  #{struct_name} * pointer = (#{struct_name} *)
      |    NUM2ULONG(rb_funcall(klass,rb_intern("rod_pointer"),0));
      |  (pointer + object_rod_id - 1)->#{name} = value;
      |}
      END
      builder.c(str.margin)
    end

    #########################################################################
    # Generated methods
    #########################################################################

    # This code intializes the class. It adds C routines and dynamic Ruby accessors.
    def self.build_structure
      self.fields.each do |name, options|
        if options[:index]
          instance_variable_set("@#{name}_index",nil)
        end
      end
      return if @structure_built

      inline(:C) do |builder|
        builder.prefix(typedef_struct)
        builder.prefix(Database.rod_exception)
        if Database.development_mode
          # This method is created to force rebuild of the C code, since
          # it is rebuild on the basis of methods' signatures change.
          builder.c_singleton("void __unused_method_#{rand(1000000)}(){}")
        end

        self.fields.each do |name, options|
          unless string_field?(options[:type])
            field_reader(name,TYPE_MAPPING[options[:type]],builder)
            field_writer(name,TYPE_MAPPING[options[:type]],builder)
          else
            field_reader("#{name}_length","unsigned long",builder)
            field_reader("#{name}_offset","unsigned long",builder)
            field_writer("#{name}_length","unsigned long",builder)
            field_writer("#{name}_offset","unsigned long",builder)
          end
        end

        singular_associations.each do |name, options|
          field_reader(name,"unsigned long",builder)
          field_writer(name,"unsigned long",builder)
          if options[:polymorphic]
            field_reader("#{name}__class","unsigned long",builder)
            field_writer("#{name}__class","unsigned long",builder)
          end
        end

        plural_associations.each do |name, options|
          field_reader("#{name}_count","unsigned long",builder)
          field_reader("#{name}_offset","unsigned long",builder)
          field_writer("#{name}_count","unsigned long",builder)
          field_writer("#{name}_offset","unsigned long",builder)
        end

        str=<<-END
        |unsigned int struct_size(){
        |  return sizeof(#{self.struct_name});
        |}
        END

        builder.c_singleton(str.margin)

        # This has to be the last position in the builder!
        self.instance_variable_set("@inline_library",builder.so_name)

        # Ruby inline generated shared library.
        def self.inline_library
          @inline_library
        end
      end

      attribute_methods = []
      ## accessors for fields, plural and singular relationships follow
      self.fields.each do |field, options|
        attribute_methods << field
        # optimization
        field = field.to_s
        # adding new private fields visible from Ruby
        # they are lazily initialized based on the C representation
        unless string_field?(options[:type])
          private "_#{field}", "_#{field}="
        else
          private "_#{field}_length", "_#{field}_offset"
        end

        unless string_field?(options[:type])
          # getter
          define_method(field) do
            value = instance_variable_get("@#{field}")
            if value.nil?
              if self.new?
                value = nil
              else
                value = send("_#{field}",@rod_id)
              end
              instance_variable_set("@#{field}",value)
            end
            value
          end

          # setter
          define_method("#{field}=") do |value|
            old_value = send(field)
            send("#{field}_will_change!") unless old_value == value
            instance_variable_set("@#{field}",value)
            value
          end
        else
          # string-type fields
          # getter
          define_method(field) do
            value = instance_variable_get("@#{field}")
            if value.nil? # first call
              if self.new?
                return (options[:type] == :object ? nil : "")
              else
                length = send("_#{field}_length", @rod_id)
                if length == 0
                  return (options[:type] == :object ? nil : "")
                end
                offset = send("_#{field}_offset", @rod_id)
                read_options = {}
                if options[:type] == :object
                  read_options[:skip_encoding] = true
                end
                value = database.read_string(length, offset, options)
                if options[:type] == :object
                  value = Marshal.load(value)
                end
                # caching Ruby representation
                # don't use writer - avoid change tracking
                instance_variable_set("@#{field}",value)
              end
            end
            value
          end

          # setter
          define_method("#{field}=") do |value|
            old_value = send(field)
            send("#{field}_will_change!") unless old_value == value
            instance_variable_set("@#{field}",value)
          end
        end

      end

      singular_associations.each do |name, options|
        attribute_methods << name
        # optimization
        name = name.to_s
        private "_#{name}", "_#{name}="
        class_name =
          if options[:class_name]
            options[:class_name]
          else
            "#{self.scope_name}::#{name.camelcase}"
          end

        #getter
        define_method(name) do
          value = instance_variable_get("@#{name}")
          if value.nil?
            return nil if self.new?
            rod_id = send("_#{name}",@rod_id)
            # the indices are shifted by 1, to leave 0 for nil
            if rod_id == 0
              value = nil
            else
              if options[:polymorphic]
                klass = Model.get_class(send("_#{name}__class",@rod_id))
                value = klass.find_by_rod_id(rod_id)
              else
                value = class_name.constantize.find_by_rod_id(rod_id)
              end
            end
            # avoid change tracking
            instance_variable_set("@#{name}",value)
          end
          value
        end

        #setter
        define_method("#{name}=") do |value|
          old_value = send(name)
          send("#{name}_will_change!") unless old_value == value
          instance_variable_set("@#{name}", value)
        end
      end

      plural_associations.each do |name, options|
        # optimization
        name = name.to_s
        class_name =
          if options[:class_name]
            options[:class_name]
          else
            "#{self.scope_name}::#{::English::Inflect.singular(name).camelcase}"
          end
        klass = options[:polymorphic] ? nil : class_name.constantize

        # getter
        define_method("#{name}") do
          proxy = instance_variable_get("@#{name}")
          if proxy.nil?
            if self.new?
              count = 0
              offset = 0
            else
              count = self.send("_#{name}_count",@rod_id)
              offset = self.send("_#{name}_offset",@rod_id)
            end
            proxy = CollectionProxy.new(count,database,offset,klass)
            instance_variable_set("@#{name}", proxy)
          end
          proxy
        end

        # count getter
        define_method("#{name}_count") do
          if (instance_variable_get("@#{name}") != nil)
            return instance_variable_get("@#{name}").count
          else
            if self.new?
              return 0
            else
              return send("_#{name}_count",@rod_id)
            end
          end
        end

        # setter
        define_method("#{name}=") do |value|
          proxy = send(name)
          value.each do |object|
            proxy << object
          end
          proxy
        end
      end

      # dirty tracking
      define_attribute_methods(attribute_methods)

      # indices
      indexed_properties.each do |property,options|
        # optimization
        property = property.to_s
        (class << self; self; end).class_eval do
          # Find all objects with given +value+ of the +property+.
          define_method("find_all_by_#{property}") do |value|
            index_for(property,options)[value]
          end

          # Find first object with given +value+ of the +property+.
          define_method("find_by_#{property}") do |value|
            index_for(property,options)[value][0]
          end
        end
      end
      @structure_built = true
    end

    class << self
      # Fields, singular and plural associations.
      def properties
        self.fields.merge(self.singular_associations.merge(self.plural_associations))
      end

      # Returns (and caches) only properties which are indexed.
      def indexed_properties
        @indexed_properties ||= self.properties.select{|p,o| o[:index]}
      end

      # Returns true if the +name+ (as symbol) is a name of a field.
      def field?(name)
        self.fields.keys.include?(name)
      end

      # Returns true if the +name+ (as symbol) is a name of a singular association.
      def singular_association?(name)
        self.singular_associations.keys.include?(name)
      end

      # Returns true if the +name+ (as symbol) is a name of a plural association.
      def plural_association?(name)
        self.plural_associations.keys.include?(name)
      end

      # Read index for the +property+ with +options+ from the database.
      def index_for(property,options)
        index = instance_variable_get("@#{property}_index")
        if index.nil?
          path = path_for_index(database.path,property)
          index = Index::Base.create(path,self,options)
          instance_variable_set("@#{property}_index",index)
        end
        index
      end

      private
      # Returns object of this class stored in the DB with given +rod_id+.
      # Warning! If wrong rod_id is specified it might cause segmentation fault exception!
      def get(rod_id)
        object = cache[rod_id]
        if object.nil?
          object = self.new(rod_id)
          cache[rod_id] = object
        end
        object
      end

    end
  end
end
