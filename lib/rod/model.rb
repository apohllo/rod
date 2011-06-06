require 'rod/constants'
require 'rod/collection_proxy'

module Rod

  # Abstract class representing a model entity. Each storable class has to derieve from +Model+.
  class Model
    include ActiveModel::Validations
    extend Enumerable

    # If +options+ is an integer it is the @rod_id of the object.
    def initialize(options=nil)
      if options.is_a?(Integer)
        @rod_id = options
      else
        @rod_id = 0
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

    # Default implementation of to_s.
    def to_s
      fields = self.class.fields.map{|n,o| "#{n}:#{self.send(n)}"}.join(",")
      singular = self.class.singular_associations.map{|n,o| "#{n}:#{self.send(n).class}"}.join(",")
      plural = self.class.plural_associations.map{|n,o| "#{n}:#{self.send(n).size}"}.join(",")
      "#{self.class}:<#{fields}><#{singular}><#{plural}>"
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
    # 'Private' API
    #########################################################################

    public
    # Update the DB information about the +object+ which
    # is referenced via singular association with +name+.
    def update_singular_association(name, object)
      object_id = object.nil? ? 0 : object.rod_id
      send("_#{name}=", @rod_id, object_id)
      if self.class.singular_associations[name][:polymorphic]
        class_id = object.nil? ? 0 : object.class.name_hash
        send("_#{name}__class=", @rod_id, class_id)
      end
    end

    # Update in the DB information about the +object+ (or objects) which is (are)
    # referenced via plural association with +name+.
    #
    # The name of the association is +name+, the referenced
    # object(s) is (are) +object+.
    # +index+ is the position of the referenced object in the association.
    # If there are many objects, the index is ignored.
    def update_plural_association(name, object, index=nil)
      offset = send("_#{name}_offset",@rod_id)
      if self.class.plural_associations[name][:polymorphic]
        # Don't refactor this code. This is due to performance hit.
        if object.respond_to?(:each)
          objects = object
          objects.each.with_index do |object,index|
            object_id = object.nil? ? 0 : object.rod_id
            class_id = object.nil? ? 0 : object.class.name_hash
            database.set_polymorphic_join_element_id(offset, index, object_id,
                                                     class_id)
          end
        else
          object_id = object.nil? ? 0 : object.rod_id
          class_id = object.nil? ? 0 : object.class.name_hash
          database.set_polymorphic_join_element_id(offset, index, object_id,
                                                   class_id)
        end
      else
        # Don't refactor this code. This is due to performance hit.
        if object.respond_to?(:each)
          objects = object
          objects.each.with_index do |object,index|
            object_id = object.nil? ? 0 : object.rod_id
            database.set_join_element_id(offset, index, object_id)
          end
        else
          object_id = object.nil? ? 0 : object.rod_id
          database.set_join_element_id(offset, index, object_id)
        end
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
        length, offset = database.set_string(value)
        send("_#{name}_length=",@rod_id,length)
        send("_#{name}_offset=",@rod_id,offset)
      else
        send("_#{name}=",@rod_id,send(name))
      end
    end

    # Stores given +object+ in the database. The object must be an
    # instance of this class.
    def self.store(object)
      unless object.is_a?(self)
        raise RodException.new("Incompatible object class #{object.class}.")
      end
      unless object.rod_id == 0
        raise RodException.new("The object #{object} is allready stored!")
      end
      database.store(self,object)

      # update indices
      self.fields.each do |field,options|
        if options[:index]
          if self.index_for(field)[object.send(field)].nil?
            # We don't use the hash default value approach,
            # since it forces the rebuild of the array
            self.index_for(field)[object.send(field)] = []
          end
          self.index_for(field)[object.send(field)] << object.rod_id
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
            referenced_objects[referenced].push([object.rod_id, name,
                                                object.class.name_hash])
          end
          # clear references, allowing for garbage collection
          object.send("#{name}=",nil)
        end
      end

      # ... via plural associations
      plural_associations.each do |name, options|
        referenced = object.send(name)
        unless referenced.nil?
          referenced.each_with_index do |element, index|
            # There are referenced objects, but their rod_id is not set
            if !element.nil? && element.rod_id == 0
              unless referenced_objects.has_key?(element)
                referenced_objects[element] = []
              end
              referenced_objects[element].push([object.rod_id, name,
                                               object.class.name_hash, index])
            end
          end
          # clear references, allowing for garbage collection
          object.send("#{name}=",nil)
        end
      end

      reverse_references = referenced_objects.delete(object)

      unless reverse_references.blank?
        reverse_references.each do |referee_rod_id, method_name, class_id, index|
          referee = Model.get_class(class_id).find_by_rod_id(referee_rod_id)
          self.cache.send(:__get_hash__).delete(referee_rod_id)
          if index.nil?
            # singular association
            referee.update_singular_association(method_name, object)
          else
            referee.update_plural_association(method_name, object, index)
          end
        end
      end
    end

    # The name of the C struct for this class.
    def self.struct_name
      return @struct_name unless @struct_name.nil?
      name = self.to_s.underscore.gsub(/\//,"__")
      unless name =~ /^\#/
        # not an anonymous class
        @struct_name = name
      end
      name
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
      begin
        subclass.add_to_database
        subclass.add_to_class_space
        subclasses << subclass
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
      @cache ||= SimpleWeakHash.new
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

    # The name of the file (for given +relative_path+), which the data of this class
    # is stored in.
    def self.path_for_data(relative_path)
      "#{relative_path}#{self.struct_name}.dat"
    end

    # The name of the file or directory (for given +relative_path+), which the
    # index of the +field+ (with +options+) of this class is stored in.
    def self.path_for_index(relative_path,field,options)
      case options[:index]
      when :flat,true
        "#{relative_path}#{self.struct_name}_#{field}.idx"
      when :segmented
        "#{relative_path}#{self.struct_name}_#{field}_idx/"
      else
        raise RodException.new("Invalid index type #{type}")
      end
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
      |#{result_type} _#{name}(unsigned long object_rod_id){
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
      |  VALUE klass = rb_funcall(self,rb_intern("class"),0);
      |  #{struct_name} * pointer = (#{struct_name} *)
      |    NUM2ULONG(rb_funcall(klass,rb_intern("rod_pointer"),0));
      |  (pointer + object_rod_id - 1)->#{name} = value;
      |}
      END
      builder.c(str.margin)
    end

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
        if Database.development_mode
          # This method is created to force rebuild of the C code, since
          # it is rebuild on the basis of methods' signatures change.
          builder.c_singleton("void __unused_method_#{rand(1000)}(){}")
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
      end

      ## accessors for fields, plural and singular relationships follow
      self.fields.each do |field, options|
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
              if @rod_id == 0
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
            instance_variable_set("@#{field}",value)
            value
          end
        else
          # string-type fields
          # getter
          define_method(field) do
            value = instance_variable_get("@#{field}")
            if value.nil? # first call
              if @rod_id == 0
                return (options[:type] == :object ? nil : "")
              else
                length = send("_#{field}_length", @rod_id)
                if length == 0
                  return (options[:type] == :object ? nil : "")
                end
                offset = send("_#{field}_offset", @rod_id)
                value = database.read_string(length, offset)
                if options[:type] == :object
                  value = Marshal.load(value)
                end
                # caching Ruby representation
                send("#{field}=",value)
              end
            end
            value
          end

          # setter
          define_method("#{field}=") do |value|
            instance_variable_set("@#{field}",value)
          end
        end

        if options[:index]
          (class << self; self; end).class_eval do
            # Read index for the +field+ from the database.
            define_method(:index_for) do |field|
              index = instance_variable_get("@#{field}_index")
              if index.nil?
                index = database.read_index(self,field,options)
                instance_variable_set("@#{field}_index",index)
              end
              index
            end

            # Find all objects with given +value+ of the +field.
            define_method("find_all_by_#{field}") do |value|
              (index_for(field)[value] || []).map{|i| get(i)}
            end

            # Find first object with given +value+ of the +field.
            define_method("find_by_#{field}") do |value|
              objects_ids = self.index_for(field)[value]
              if objects_ids
                get(objects_ids[0])
              else
                nil
              end
            end
          end
        end
      end

      singular_associations.each do |name, options|
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
            send("#{name}=",value)
          end
          value
        end

        #setter
        define_method("#{name}=") do |value|
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
            "#{self.scope_name}::#{::English::Inflect.
              singular(name).camelcase}"
          end

        # getter
        define_method("#{name}") do
          values = instance_variable_get("@#{name}")
          if values.nil?
            if @rod_id == 0
              count = 0
            else
              count = self.send("_#{name}_count",@rod_id)
            end
            return instance_variable_set("@#{name}",[]) if count == 0
            unless options[:polymorphic]
              klass = class_name.constantize
              values = database.
                join_indices(self.send("_#{name}_offset",@rod_id),count).
                map do |rod_id|
                rod_id == 0 ? nil : klass.find_by_rod_id(rod_id)
              end
            else
              values = database.
                polymorphic_join_indices(self.send("_#{name}_offset",@rod_id),count).
                map do |rod_id,class_id|
                rod_id == 0 ? nil : Model.get_class(class_id).find_by_rod_id(rod_id)
              end
            end
            instance_variable_set("@#{name}", values)
          end
          values
        end

        # count getter
        define_method("#{name}_count") do
          if (instance_variable_get("@#{name}") != nil)
            return instance_variable_get("@#{name}").count
          else
            return send("_#{name}_count",@rod_id)
          end
        end

        # setter
        define_method("#{name}=") do |value|
          instance_variable_set("@#{name}", value)
        end
      end
      @structure_built = true
    end

    class << self
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
