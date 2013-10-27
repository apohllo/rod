require 'singleton'

module Rod
  module Database
    # This class is reposponsible for storing mapping between databases and
    # resources. Since a resource might be connected with many DBs, the mapping
    # provides 'default' connections.
    class Registry
      include Singleton

      def initialize
        @databases = {}
        @resources_to_ids = {}
        @ids_to_resources = Hash.new{|h,e| h[e] = [] }
        @resources_to_containers = {}
      end

      # Clears the registry
      def clear
        @databases.clear
        @resources_to_ids.clear
        @ids_to_resources.clear
        @resources_to_containers.clear
      end

      # Register a +database+ with the given +id+ in the registry.
      def register_database(database)
        @databases[database.id] = database
      end

      # Registers the containers of the +database+ as associated with their
      # resources.
      def register_containers(database)
        raise DatabaseError.new("Database is not registered") unless @databases[database.id]
        database.containers.each do |container|
          @resources_to_containers[[container.resource,database.id]] = container
        end
      end

      # Registers default database +id+ for the given +resource+.
      def register_resource(id,resource)
        @resources_to_ids[resource] = id
        @ids_to_resources[id] << resource
      end

      # Returns the database for a given +resource+.
      def find_database_by_resource(resource)
        @databases[@resources_to_ids[resource]]
      end

      # Returns the default container storing the data for a given
      # +resource+. The default database id of the resource is used, it the
      # +db_id+ is not provided.
      def find_container_by_resource(resource,db_id=nil)
        db_id ||= resource.database_id
        @resources_to_containers[[resource,db_id]]
      end

      # Returns the database with the given +id+.
      def find_database_by_id(id)
        @databases[id]
      end

      # Removes the database with the given +id+ from the registry.
      def remove_database(id)
        @databases.delete(id)
        @resources_to_containers.delete_if do |(resource,db_id),container|
          db_id == id
        end
      end

      # Returns resources registered for a database with given +db+ id or the
      # +db+ itself.
      def resources_for(db_id)
        case db_id
        when Symbol
          @ids_to_resources[db_id]
        else
          @ids_to_resources[db_id.id]
        end
      end

      # Returns the id of the database for a given +resource+.
      def database_id_for_resource(resource)
        @resources_to_ids[resource]
      end
    end
  end
end
