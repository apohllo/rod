module Rod
  module Native
    # The container class is responsible for storing all data associated with
    # a given resource. It achieves its goal by splitting the data into pieces and
    # managing several stores for structures and sequences.
    class Container
      # The path where the container stores the data.
      attr_reader :path

      # The store where values of fixed fields and association
      # data is kept.
      attr_reader :structures

      # The file extension of the structures store.
      STRUCTERS_SUFFIX = ".rod"

      # The store where variable size values are kept.
      attr_reader :sequences

      # The file extension of the sequences store.
      BYTES_SUFFIX = ".bin.rod"

      # The indirect addressing store for monomorphic plural associations.
      attr_reader :monomorphic_store

      # The file extension of the monomorphic store.
      MONOMORPHIC_SUFFIX = ".mon.rod"

      # The indirect addressing store for polymorphic plural associations.
      attr_reader :polymorphic_store

      # The file extension of the polymorphic store.
      POLYMORPHIC_SUFFIX = ".pol.rod"

      # The file extension of an index.
      INDEX_SUFFIX = ".idx"

      # The resource associated with this container.
      attr_reader :resource

      # Initialize this container with given +path+, associated with the
      # +resource+ and initialized using the +metadata+.
      # Options:
      # * +:cache_factory+ - factory used to create the cache
      # * +:structures_factory+ - factory used to create structure stores
      # * +:sequences_factory+ - factory used to create sequence stores
      # * +:readonly+ - flag indicating if the conainer works in read-only mode
      def initialize(path,resource,metadata,cache_factory: Cache,
                     structures_factory: StructureStore,
                     sequences_factory: SequenceStore,
                     index_factory: Index::HashIndex,
                     readonly: true)
        raise InvalidArgument.new(nil,"path") if path.nil?
        raise InvalidArgument.new(nil,"resource") if resource.nil?
        raise InvalidArgument.new(nil,"metadata") if metadata.nil?

        @opened = false
        @readonly = readonly
        @path = path
        @resource = resource
        @accessors = []
        @indices = {}
        @updaters = []

        @resource.finalize

        offsets = [0]
        resource.properties.each do |property|
          offsets << offsets.last + property.size
        end

        @structures = structures_factory.new(path + STRUCTERS_SUFFIX,offsets.last,
                                               metadata.element_count,readonly)
        @sequences = sequences_factory.
          new(path + BYTES_SUFFIX,metadata.byte_count,readonly)
        @monomorphic_store = structures_factory.
          new(path + MONOMORPHIC_SUFFIX,1,metadata.monomorphic_count,readonly)
        @polymorphic_store = structures_factory.
          new(path + POLYMORPHIC_SUFFIX,2,metadata.polymorphic_count,readonly)

        resource.properties.zip(offsets).each do |property,offset|
          @accessors << property.accessor(self,offset)
        end

        resource.indexed_properties.each do |property|
          @indices[property] = index_factory.new(path + "_#{property.name}#{INDEX_SUFFIX}",resource)
          @updaters << property.updater(@indices[property])
        end
        @counter = metadata.element_count

        @cache = cache_factory.new
      end

      # Returns true if the container was opened, i.e. values might
      # be saved and read from it.
      def opened?
        @opened
      end

      # Returns true if the container is/will be opened in readonly state.
      def readonly?
        @readonly
      end

      # Open the container.
      def open(options={})
        raise DatabaseError.new("Container already opened.") if opened?
        if block_given?
          begin
            yield
          ensure
            close()
          end
        else
          @structures.open
          @sequences.open
          @monomorphic_store.open
          @polymorphic_store.open
          @opened = true
        end
      end

      # Close the container.
      def close
        # TODO save the resources index!!!
        #r.indices.each{|i| i.save }
        @cache.clear
        @opened = false
      end

      # Save the +object+ in the container. The save is performed by
      # updating in the DB the values of fields and associations
      # that were changed. It also updates the relevant indices.
      def save(object)
        unless object.is_a?(@resource)
          raise RodException.new("Incompatible object class #{object.class}.")
        end
        if object.new?
          object.rod_id = next_rod_id
          @structures.allocate_elements(1)
        end
        @structures.element_count
        @cache[object.rod_id] = object
        @accessors.each{|accessor| accessor.save(object) }
        @updaters.each{|updater| updater.update(object) }
      end

      # Load the object with given +rod_id+. The object is retrieved
      # from cache if it was already loaded. This ensures referential
      # integrity (i.e. DB implements identity map).
      def load(rod_id)
        return @cache[rod_id] if @cache.has_key?(rod_id)
        object = @resource.new
        object.rod_id = rod_id
        @accessors.each{|accessor| accessor.load(object) }
        @cache[rod_id] = object
      end

      # Returns the number of elements (structures) stored in the container.
      def element_count
        @structures.element_count
      end

      # Returns the number of bytes stored in the container.
      def byte_count
        @sequences.element_count
      end

      # Returns the number of indirectly referenced monomorphic elements.
      def monomorphic_count
        @monomorphic_store.element_count
      end

      # Returns the number of indirectly referenced polymorphic elements.
      def polymorphic_count
        @polymorphic_store.element_count
      end

      # String representation of the container.
      def inspect
        "#{self.class}:#{self.object_id}<readonly:#{@readonly}, resource:#{@resource.name}>"
      end

      protected
      def next_rod_id
        @counter += 1
      end
    end
  end
end
