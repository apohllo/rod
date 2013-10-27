module Rod
  module Model
    module Resource
      module ClassMethods
        attr_writer :registry_factory

        # Returns the number of objects of this class stored in the
        # container.
        def count
          self_count = container.element_count
          # This should be changed if all other featurs connected with
          # inheritence are implemented, especially #14
          #including_classes.inject(self_count){|sum,sub| sum + sub.count}
          self_count
        end

        # Returns the default container associated with this resource.
        def container
          @container = database_registry.find_container_by_resource(self)
        end

        # Set the id of the default database connected with this model.
        # This value is inherited by children, so it desn't have to be called for
        # each resource separately.
        def database_id=(id)
          @database_id = id
        end

        # Returns the id of the default database associated with this resource.
        def database_id
          return @database_id unless @database_id.nil?
          @database_id = superclass.database_id
        rescue NoMethodError
          @database_id = :default
        end


        # Returns n-th (+index+) object of this class stored in the database.
        # This call is scope-checked. So far negative indices are not supported.
        def [](index)
          begin
            container.load(index+1)
          rescue IndexError
            nil
          end
        end

        # Registers the class in the class space of resources and the database
        # it belongs to.
        def register
          resource_space.add(self)
          database_registry.register_resource(self.database_id,self)
        end

        # Inherited has to be overloaded, to register the inheriting class
        # in the class space of resources and the database it belongs to.
        def inherited(subclass)
          super
          subclass.register
        end

        # Finalizes the resource, i.e. changes made to its structure are
        # ignored. The actual property structure is used as the reference when
        # storing and loding the resource to/from DB.
        def finalize
          return if @finalized
          self.attribute_set.each{|a| virtus_adapter.convert_attribute(a,self) }
          @finalized = true
        end

=begin
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

        # This code intializes the class. It adds C routines and dynamic Ruby accessors.
        def build_structure
          self.indexed_properties.each do |property|
            property.reset_index
          end
          return if @structure_built
        end

        # Finder for rod_id.
        def find_by_rod_id(rod_id)
          if rod_id <= 0 || rod_id > self.count
            return nil
          end
          get(rod_id)
        end
=end

        private
        # The resource space given resource belongs to.
        def resource_space
          resource_space_factory.instance
        end

        # The database registry given resource belongs to.
        def database_registry
          database_registry_factory.instance
        end

        # The virtus adapter used to convert the attributes to properties.
        def virtus_adapter
          @virtus_adapter ||= virtus_adapter_factory.new
        end

        # The resource space factory.
        def resource_space_factory
          ResourceSpace
        end

        # The database Registry factory.
        def database_registry_factory
          Database::Registry
        end

        # The virtus adapter factory
        def virtus_adapter_factory
          Property::VirtusAdapter
        end
      end
    end
  end
end
