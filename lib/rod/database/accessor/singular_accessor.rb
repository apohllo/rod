require_relative 'base'

module Rod
  module Database
    module Accessor
      # The accessor is used to load and save singular associations
      # of objects from and to the database.
      class SingularAccessor < Base
        UTF_8 = "utf-8".freeze

        # Initialize the accessor with +property+, object +database+,
        # +resource_space+ and +updater_factory+.
        #
        # The +resource_space+ is used to retrieve polymorphic associations
        # while the +updater_factory+ is used to create updaters when
        # the associated object is not yet stored in the database.
        def initialize(property,database,resource_space,updater_factory)
          super(property,database)
          @resource_space = resource_space
          @updater_factory = updater_factory
        end

        # Save the value of the property of the +object+ to the database.
        def save(object)
          other = read_property(object)
          rod_id = other.nil? ? 0 : other.rod_id
          updater = ->(){ @database.write_ulong(object_offset(object),
                                                @property.offset,rod_id) }
          if other && other.new?
            @resource_space.database_for(other.resource,@database).
              register_updater(other,updater)
          else
            updater.call
          end
          if @property.polymorphic?
            @database.write_ulong(object_offset(object),@property.offset+1,
                                  @resource_space.name_hash(other.resource))
          end
        end

        # Load the value of the property of the +object+ from the database.
        def load(object)
          rod_id = @database.read_ulong(object_offset(object),@property.offset)
          if rod_id == 0
            write_property(object,nil)
          else
            resource =
              if @property.polymorphic?
                resource_hash = @database.
                  read_ulong(object_offset(object),@property.offset+1)
                @resource_space.get(resource_hash)
              else
                @property.resource
              end
            other = @resource_space.database_for(resource,@database).
              find_by_rod_id(rod_id)
            write_property(object,other)
          end
        end
      end
    end
  end
end
