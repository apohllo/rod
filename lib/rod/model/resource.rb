# encoding: utf-8

=begin
require 'rod/model/migration'
require 'rod/model/name_conversion'
require 'rod/model/class_space'
=end
require 'set'

require 'rod/model/class_methods'
require 'rod/property/class_methods'

module Rod
  module Model
    # The core module of the ROD library. Any class that has to be
    # storable in ROD has to include this module.
    #
    # The module uses Virtus to define the attributes that are stored in the
    # database.
    #
    # A basic definition of a class looks as follows:
    # class Person
    #   include Rod.resource
    #   attribute :name, String
    #   attribute :surname, String, :index => :hash
    #   attribute :address, Address
    #   attribute :children, Array[Person]
    # end
    #
    # You can set an index on the fields. In that case you can use
    # find_(all_)by_name-of-the-field accessors, to get the specific object.
    # Otherwise these call is not available.
    #
    # Consult the Rod::Property::Field and Rod::Index::Base classes
    # to find out more about filed types and indexing.
    #
    # The are only two types of associations in ROD: has_one and has_many.
    # There is no has_and_belongs_to_many association, since the association
    # model is different than in relational database - the association is not
    # symetric by default. It also mean that you are responsible for creating
    # the connection in both directions. At present it is not possible to
    # automatically create the inverse, even if there is a proper association
    # on the other side.
    #
    # The names of the association classes are inferred from the names
    # of the associations (as in ActiveRecord). You can override this behavior
    # by providing the :class_name option. This means that on the other side,
    # there are object only of particular type. But it is possible to
    # create polymorphic associations by providing :polymorphic option.
    # In such case, the hash of the name of the class is stored together
    # with the association and it allows for selecting the proper class
    # when the association is accessed.
    #
    # The associations are also indexible. In most of the cases it is better
    # to create an inverse association, however. There is only one case you
    # would prefere the index - if you have two separate database, both
    # having objects with cross-database associations. Such associations
    # are not allowed in ROD, but on the side that defines the association
    # you can define an index. That index will serve as the reverse association.
    #
    # To find out more about the association check out the
    # Rod::Property::SingularAssociation and Rod::Property::PluralAssociation
    # classes.
    module Resource
      # The id of the resource - unique for a combination of resource type and
      # container.
      attr_accessor :rod_id

      # Be sure to call super when you override this
      # method. Most of ROD feature won't be available
      # otherwise!
      def self.included(base)
        super
        base.__send__(:extend,ClassMethods)
        base.__send__(:extend,Property::ClassMethods)
        base.__send__(:include,ActiveModel::Dirty)
        base.__send__(:include,ActiveModel::Validations)
        base.__send__(:include,Virtus)
=begin
        base.__send__(:extend,Enumerable)
        base.__send__(:extend,Migration)
=end
        base.register
      end

=begin
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
=end

      # Stores the instance in the database. This might be called
      # only if the database is opened for writing (see +create+).
      # To skip validation pass +false+.
      #
      # The object keeps track of the changes of the fields and
      # singular associations, so they are not stored, if they haven't
      # changed. The plural associations are always updated, but
      # the collection proxy has it's dirty tracking mechanism.
      #
      # If there are objects with associations to this object
      # that had been stored, before this object has been stored, they
      # are notified in order to fix the association. It also means that
      # if you stop the storage of objects in the middle you will have
      # objects with invalid associations.
      def store(validate=true)
        if validate
          if valid?
            container.save(self)
          else
            raise ValidationException.new([self.to_s,self.errors.full_messages])
          end
        else
          container.save(self)
        end
=begin
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
=end
        # XXX we don't use the 'previously changed' feature, since the simplest
        # implementation requires us to leave references to objects, which
        # forbids them to be garbage collected.
        @changed_attributes.clear unless @changed_attributes.nil?
      end

      # Returns the container given instance belongs to (is or will be stored in).
      def container
        @container ||= registry.find_container_by_resource(self.class)
      end

      # Returns +true+ if the object hasn't been persisted yet.
      def new?
        @rod_id.nil? || @rod_id == 0
      end

      # Returns the properties that were changed from the last save.
      def changed_properties
        changed_names = Set.new(self.changed)
        self.class.properties.select{|p| changed_names.include?(p.name) }
      end

      # Default implementation of equality.
      def ==(other)
        self.class == other.class && self.rod_id == other.rod_id
      end

      # Default implementation of +inspect+.
      def inspect
        fields = self.class.fields.map{|p| "#{p.name}:#{self.send(p.name)}"}.join(",")
        singular = self.class.singular_associations.
          map{|p| "#{p.name}:#{self.send(p.name).class}"}.join(",")
        plural = self.class.plural_associations.
          map{|p| "#{p.name}:#{self.send(p.name).size}"}.join(",")
        "#{self.class}<#{fields}><#{singular}><#{plural}>"
      end

      # Default implementation of +to_s+.
      def to_s
        self.inspect
      end

    private
      def registry
        @registry ||= registry_factory.instance
      end

      def registry_factory
        Database::Registry
      end

=begin
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
=end
    end
  end
end
