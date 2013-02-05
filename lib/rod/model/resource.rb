# encoding: utf-8

require 'rod/model/simple_resource'
require 'rod/model/migration'
require 'rod/model/name_conversion'
require 'rod/model/class_space'

require 'rod/property/class_methods'

module Rod
  module Model
    module Resource
      # A list of updaters that has to be notified when the +rod_id+
      # of this object is defined. See ReferenceUpdater for details.
      attr_reader :reference_updaters

      # Returns the class space of the resources, i.e. all classes
      # that are defined as resource.
      def self.class_space
        @class_space ||= ClassSpace.new
      end

      # Sets the class space for the resources.
      def self.class_space=(class_space)
        @class_space = class_space
      end

      def self.included(base)
        super
        base.__send__(:include,ActiveModel::Dirty)
        base.__send__(:include,ActiveModel::Validations)
        base.__send__(:extend,NameConversion)
        base.__send__(:extend,Enumerable)
        base.__send__(:extend,Migration)
        base.__send__(:extend,SimpleResource)
        base.__send__(:extend,Property::ClassMethods)
        base.__send__(:extend,Database::ClassMethods)
        base.__send__(:extend,ClassMethods)
        base.register(self.class_space)
      end

      #########################################################################
      # Public API
      #########################################################################

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
            property.update(self)
          elsif property.singular?
            # store singular association value
            property.update(self,__send__(property_name))
          else
            # Plural associations are not tracked.
            raise RodException.new("Invalid changed property #{self.class}##{property}'")
          end
        end
        # store plural associations in the DB
        self.class.plural_associations.each do |property|
          collection = __send__(property.name)
          offset = collection.save
          property.update(self,collection.size,offset)
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
        singular = self.class.singular_associations.
          map{|p| "#{p.name}:#{self.send(p.name).class}"}.join(",")
        plural = self.class.plural_associations.
          map{|p| "#{p.name}:#{self.send(p.name).size}"}.join(",")
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

      # Returns the database given instance belongs to (is or will be stored within).
      def database
        self.class.database
      end

      # Returns the class space, the class of this object belongs to.
      def class_space
        self.class.class_space
      end

      protected
      # Sets the default values for fields.
      def initialize_fields
        self.class.fields.each do |field|
          next if field.name == :rod_id
          send("#{field.name}=",field.default_value)
        end
      end

      module ClassMethods
        # The class space is the set of classes that included Resource.
        attr_accessor :class_space

        # Returns the number of objects of this class stored in the
        # database.
        def count
          self_count = database.count(self)
          # This should be changed if all other featurs connected with
          # inheritence are implemented, especially #14
          #including_classes.inject(self_count){|sum,sub| sum + sub.count}
          self_count
        end

        # Iterates over object of this class stored in the database.
        def each
          #TODO an exception if in wrong state?
          if block_given?
            count.times do |index|
              yield get(index+1)
            end
          else
            enum_for(:each)
          end
        end

        # Returns n-th (+index+) object of this class stored in the database.
        # This call is scope-checked.
        def [](index)
          begin
            get(index+1)
          rescue IndexError
            nil
          end
        end

        # Returns the metadata for the resource.
        # If the +metadata_factory+ is provided, it is
        # used to create the metadata. By default this is
        # ResourceMetadata class.
        def metadata(metadata_factory=ResourceMetadata)
          super(metadata_factory)
        end

        # The module context of the class.
        def module_context
          context = name[0...(name.rindex( '::' ) || 0)]
          context.empty? ? Object : eval(context)
        end

        # Returns the name of the scope of the class.
        def scope_name
          if self.module_context == Object
            ""
          else
            self.module_context.to_s
          end
        end

        # Converts the name of the including model to the C struct name.
        def struct_name
          return @struct_name unless @struct_name.nil?
          name = NameConversion.struct_name_for(self.to_s)
          unless name =~ /^\#/
            # not an anonymous class
            @struct_name = name
          end
          name
        end

        # The C structure representing this class.
        def typedef_struct
          result = <<-END
          |typedef struct {
          |  \n#{self.properties.map do |property|
            property.to_c_struct
          end.join("\n|  \n")}
          |} #{struct_name()};
          END
          Utils.remove_margin(result)
        end

        # Registers the class in class space of resources and the database
        # it belongs to.
        def register(class_space)
          class_space.add(self)
          begin
            self.add_to_database
          rescue MissingDatabase
            # This might happen for classes which include directly
            # the Rod::Model::Resource. Since the +included+ method is always called
            # before the +database_class+ call, they never have the DB set-up
            # when this is called.
            # +add_to_database+ is called within +database_class+ for them.
          end
        end

        # Inherited has to be overloaded, to register the inheriting class
        # in the class space of resources and the database it belongs to.
        def inherited(subclass)
          super
          subclass.register(self.class_space)
        end

        # This code intializes the class. It adds C routines and dynamic Ruby accessors.
        def build_structure
          self.indexed_properties.each do |property|
            property.reset_index
          end
          return if @structure_built

          inline(:C) do |builder|
            builder.include '<stdint.h>'
            builder.prefix(Index::HashIndex.endianess)
            builder.prefix(typedef_struct)
            builder.prefix(Native::Database.rod_exception)
            if Database::Base.development_mode
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

            builder.c_singleton(Utils.remove_margin(str))

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

        # Stores given +object+ in the database. The object must be an
        # instance of this class.
        def store(object)
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

        # Finder for rod_id.
        def find_by_rod_id(rod_id)
          if rod_id <= 0 || rod_id > self.count
            return nil
          end
          get(rod_id)
        end

        #########################################################################
        # DB-oriented API
        #########################################################################

        # Allows for setting arbitrary name for the model path, i.e.
        # the model-specific fragment of the path to the model files.
        # By default it is the same as Model::NameConversion.struct_name
        def model_path=(path)
          @model_path = path
        end

        # Returns the model path, i.e. the model-specific fragment of
        # the path to the model files (data, indices, etc.).
        def model_path
          @model_path || self.struct_name
        end

        # The name of the file (for given +relative_path+), which the data of this class
        # is stored in.
        def path_for_data(relative_path)
          "#{relative_path}#{model_path}.dat"
        end

        # Prints the memory layout of the structure.
        def layout
          self.properties.map do |property|
            property.layout
          end.join("\n")
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
end
