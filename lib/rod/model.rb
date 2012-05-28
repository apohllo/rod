require 'rod/constants'
require 'rod/collection_proxy'
require 'rod/abstract_model'

module Rod

  # Abstract class representing a model entity. Each storable class has to derieve from +Model+.
  class Model < AbstractModel
    include ActiveModel::Validations
    include ActiveModel::Dirty
    extend Utils
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
      self.changed.each do |property_name|
        property = self.class.property(property_name.to_sym)
        if property.field?
          # store field value
          update_field(property)
        elsif property.singular?
          # store singular association value
          update_singular_association(property,send(property_name))
        else
          # Plural associations are not tracked.
          raise RodException.new("Invalid changed property #{self.class}##{property}'")
        end
      end
      # store plural associations in the DB
      self.class.plural_associations.each do |property|
        collection = send(property.name)
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
      fields = self.class.fields.map{|p| "#{p.name}:#{self.send(p.name)}"}.join(",")
      singular = self.class.singular_associations.map{|p| "#{p.name}:#{self.send(p.name).class}"}.join(",")
      plural = self.class.plural_associations.map{|p| "#{p.name}:#{self.send(p.name).size}"}.join(",")
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
      self.class.properties.each do |property|
        next if property.association? && property.plural?
        result[property.name.to_s] = self.send(property.name)
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
      begin
        get(index+1)
      rescue IndexError
        nil
      end
    end

    protected
    # Sets the default values for fields.
    def initialize_fields
      self.class.fields.each do |field|
        next if field.name == :rod_id
        send("#{field.name}=",field.default_value)
      end
    end

    # A macro-style function used to indicate that given piece of data
    # is stored in the database. See Rod::Property::Field for valid
    # types and options.
    #
    # Warning!
    # :rod_id is a predefined field
    def self.field(name, type, options={})
      if self.property(name)
        raise InvalidArgument.new(name,"doubled property name")
      end
      self.fields << Property::Field.new(self,name,type,options)
      # clear cached properties
      @properties = nil
    end

    # A macro-style function used to indicate that instances of this
    # class are associated with many instances of some other class. The
    # name of the class is guessed from the property name, but you can
    # change it via options.
    # Options:
    # * +:class_name+ - the name of the class (as String) associated
    #   with this class
    # * +:polymorphic+ - if set to +true+ the association is polymorphic (allows to acess
    #   objects of different classes via this association)
    def self.has_many(name, options={})
      if self.property(name)
        raise InvalidArgument.new(name,"doubled property name")
      end
      self.plural_associations << Property::PluralAssociation.new(self,name,options)
      # clear cached properties
      @properties = nil
    end

    # A macro-style function used to indicate that instances of this
    # class are associated with one instance of some other class. The
    # name of the class is guessed from the property name, but you can
    # change it via options. See Rod::Property::SingularAssociation for details.
    def self.has_one(name, options={})
      if self.property(name)
        raise InvalidArgument.new(name,"doubled property name")
      end
      self.singular_associations << Property::SingularAssociation.new(self,name,options)
      # clear cached properties
      @properties = nil
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

    # Rebuild the index for given +property+. If the property
    # doesn't have an index, an exception is raised.
    def self.rebuild_index(property)
      if property.options[:index].nil?
        raise RodException.new("Property '#{property.name}' doesn't have an index!")
      end
      index = property.index
      index.destroy
      self.each.with_index do |object,position|
        index[object.send(property.name)] << object
        report_progress(position,self.count) if $ROD_DEBUG
      end
    end

    #########################################################################
    # 'Private' instance methods
    #########################################################################

    public
    # Update the DB information about the +object+ which
    # is referenced via singular association +property+.
    # If the object is not yet stored, a reference updater
    # is registered to update the DB when it is stored.
    def update_singular_association(property, object)
      if object.nil?
        rod_id = 0
      else
        if object.new?
          # There is a referenced object, but its rod_id is not set.
          object.reference_updaters << ReferenceUpdater.
            for_singular(self,property,self.database)
          return
        else
          rod_id = object.rod_id
        end
        # clear references, allowing for garbage collection
        # WARNING: don't use writer, since we don't want this change to be tracked
        #object.instance_variable_set("@#{name}",nil)
      end
      send("_#{property.name}=", @rod_id, rod_id)
      if property.polymorphic?
        class_id = object.nil? ? 0 : object.class.name_hash
        send("_#{property.name}__class=", @rod_id, class_id)
      end
    end

    # Updates in the DB the +count+ and +offset+ of elements for +property+ association.
    def update_count_and_offset(property,count,offset)
      send("_#{property.name}_count=",@rod_id,count)
      send("_#{property.name}_offset=",@rod_id,offset)
    end

    # Updates in the DB the field +property+ to the actual value.
    def update_field(property)
      if property.variable_size?
        value = property.dump(send(property.name))
        length, offset = database.set_string(value)
        send("_#{property.name}_length=",@rod_id,length)
        send("_#{property.name}_offset=",@rod_id,offset)
      else
        send("_#{property.name}=",@rod_id,send(property.name))
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
      indexed_properties.each do |property|
        # WARNING: singular and plural associations with nil as value are not indexed!
        # TODO #156 think over this constraint, write specs in persistence.feature
        if property.field? || property.singular?
          if stored_now || object.changes.has_key?(property.name.to_s)
            unless stored_now
              old_value = object.changes[property.name.to_s][0]
              property.index[old_value].delete(object)
            end
            new_value = object.send(property.name)
            if property.field? || new_value
              property.index[new_value] << object
            end
          end
        else
          # plural
          object.send(property.name).deleted.each do |deleted|
            property.index[deleted].delete(object) unless deleted.nil?
          end
          object.send(property.name).added.each do |added|
            property.index[added] << object unless added.nil?
          end
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
        @fields ||= [Property::Field.new(self,:rod_id,:ulong)]
      else
        @fields ||= superclass.fields.map{|p| p.copy(self)}
      end
    end

    # Returns singular associations of this class.
    def self.singular_associations
      if self == Rod::Model
        @singular_associations ||= []
      else
        @singular_associations ||= superclass.singular_associations.map{|p| p.copy(self)}
      end
    end

    # Returns plural associations of this class.
    def self.plural_associations
      if self == Rod::Model
        @plural_associations ||= []
      else
        @plural_associations ||= superclass.plural_associations.map{|p| p.copy(self)}
      end
    end

    # Metadata for the model class.
    def self.metadata
      meta = super
      {:fields => :fields,
       :has_one => :singular_associations,
       :has_many => :plural_associations}.each do |type,method|
        # fields
        metadata = {}
        self.send(method).each do |property|
          next if property.field? && property.identifier?
          metadata[property.name] = property.metadata
        end
        unless metadata.empty?
          meta[type] = metadata
        end
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
          next if superclass.property(name)
          if type == :fields
            internal_options = options.dup
            field_type = internal_options.delete(:type)
            klass.send(:field,name,field_type,internal_options)
          else
            klass.send(type,name,options)
          end
        end
      end
      klass
    end

    # Migrates the class to the new model, i.e. it copies all the
    # values of properties that both belong to the class in the old
    # and the new model; it initializes new properties with default
    # values and migrates the indices to different implementations.
    def self.migrate
      # check if the migration is needed
      old_metadata = self.metadata
      old_metadata.merge!({:superclass => old_metadata[:superclass].sub(LEGACY_RE,"")})
      new_class = self.name.sub(LEGACY_RE,"").constantize
      if new_class.compatible?(old_metadata)
        backup_path = self.path_for_data(database.path)
        new_path = new_class.path_for_data(database.path)
        puts "Copying #{backup_path} to #{new_path}" if $ROD_DEBUG
        FileUtils.cp(backup_path,new_path)
        new_class.indexed_properties.each do |property|
          backup_path = self.property(property.name).index.path
          new_path = property.index.path
          puts "Copying #{backup_path} to #{new_path}" if $ROD_DEBUG
          FileUtils.cp(backup_path,new_path)
        end
        return
      end
      database.send(:allocate_space,new_class)

      puts "Migrating #{new_class}" if $ROD_DEBUG
      # Check for incompatible properties.
      self.properties.each do |name,property|
        next unless new_class.property(name)
        difference = property.difference(new_class.properties[name])
        difference.delete(:index)
        # Check if there are some options which we cannot migrate at the
        # moment.
        unless difference.empty?
          raise IncompatibleVersion.
            new("Incompatible definition of property '#{name}'\n" +
                "Definition of '#{name}' is different in the old and "+
                "the new schema for '#{new_class}':\n" +
                "  #{difference}")
        end
      end
      # Migrate the objects.
      # initialize prototype objects
      old_object = self.new
      new_object = new_class.new
      self.properties.each do |property|
        # optimization
        name = property.name.to_s
        next unless new_class.property(name.to_sym)
        print "-  #{name}... " if $ROD_DEBUG
        if property.field?
          if property.variable_size?
            self.count.times do |position|
              new_object.send("_#{name}_length=",position+1,
                              old_object.send("_#{name}_length",position+1))
              new_object.send("_#{name}_offset=",position+1,
                              old_object.send("_#{name}_offset",position+1))
              report_progress(position,self.count) if $ROD_DEBUG
            end
          else
            self.count.times do |position|
              new_object.send("_#{name}=",position + 1,
                              old_object.send("_#{name}",position + 1))
              report_progress(position,self.count) if $ROD_DEBUG
            end
          end
        elsif property.singular?
          self.count.times do |position|
            new_object.send("_#{name}=",position + 1,
                            old_object.send("_#{name}",position + 1))
            report_progress(position,self.count) if $ROD_DEBUG
          end
          if property.polymorphic?
            self.count.times do |position|
              new_object.send("_#{name}__class=",position + 1,
                              old_object.send("_#{name}__class",position + 1))
              report_progress(position,self.count) if $ROD_DEBUG
            end
          end
        else
          self.count.times do |position|
            new_object.send("_#{name}_count=",position + 1,
                            old_object.send("_#{name}_count",position + 1))
            new_object.send("_#{name}_offset=",position + 1,
                            old_object.send("_#{name}_offset",position + 1))
            report_progress(position,self.count) if $ROD_DEBUG
          end
        end
        puts " done" if $ROD_DEBUG
      end
      # Migrate the indices.
      new_class.indexed_properties.each do |property|
        # Migrate to new options.
        old_index_type = self.property(property.name) && self.property(property.name).options[:index]
        if old_index_type.nil?
          print "-  building index #{property.options[:index]} for '#{property.name}'... " if $ROD_DEBUG
          new_class.rebuild_index(property)
          puts " done" if $ROD_DEBUG
        elsif property.options[:index] == old_index_type
          backup_path = self.property(property.name).index.path
          new_path = property.index.path
          puts "Copying #{backup_path} to #{new_path}" if $ROD_DEBUG
          FileUtils.cp(backup_path,new_path)
        else
          print "-  copying #{property.options[:index]} index for '#{property.name}'... " if $ROD_DEBUG
          new_index = property.index
          old_index = self.property(property.name).index
          new_index.copy(old_index)
          puts " done" if $ROD_DEBUG
        end
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

    # The C structure representing this class.
    def self.typedef_struct
      result = <<-END
      |typedef struct {
      |  \n#{self.properties.map do |property|
        property.to_c_struct
      end.join("\n|  \n")}
      |} #{struct_name()};
      END
      result.margin
    end

    # Prints the memory layout of the structure.
    def self.layout
      self.properties.map do |property|
        property.layout
      end.join("\n")
    end


    #########################################################################
    # Generated methods
    #########################################################################

    # This code intializes the class. It adds C routines and dynamic Ruby accessors.
    def self.build_structure
      self.indexed_properties.each do |property|
        property.reset_index
      end
      return if @structure_built

      inline(:C) do |builder|
        builder.include '<byteswap.h>'
        builder.include '<endian.h>'
        builder.include '<stdint.h>'
        builder.prefix(typedef_struct)
        builder.prefix(Database.rod_exception)
        if Database.development_mode
          # This method is created to force rebuild of the C code, since
          # it is rebuild on the basis of methods' signatures change.
          builder.c_singleton("void __unused_method_#{rand(1000000)}(){}")
        end

        self.properties.each do |property|
          property.define_c_accessors(builder)
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
      properties.each do |property|
        if property.field? || property.singular?
          attribute_methods << property.name
        end
        property.seal_c_accessors
        property.define_getter
        property.define_setter
        property.define_finders
      end

      # dirty tracking
      define_attribute_methods(attribute_methods)

      @structure_built = true
    end

    class << self
      # Fields, singular and plural associations.
      def properties
        @properties ||= self.fields + self.singular_associations + self.plural_associations
      end

      # Returns the property with given +name+ or nil if it doesn't exist.
      def property(name)
        properties.find{|p| p.name == name}
      end

      # Returns (and caches) only properties which are indexed.
      def indexed_properties
        @indexed_properties ||= self.properties.select{|p| p.options[:index]}
      end

      private
      # Returns object of this class stored in the DB with given +rod_id+.
      # Warning! If wrong rod_id is specified it might cause segmentation fault error!
      def get(rod_id)
        object = cache[rod_id]
        if object.nil?
          if rod_id <= 0 || rod_id > self.count
            raise IndexError.new("Invalid rod_id #{rod_id} for #{self}")
          end
          object = self.new(rod_id)
          cache[rod_id] = object
        end
        object
      end
    end
  end
end
