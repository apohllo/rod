# encoding: utf-8
require 'rod/utils'

module Rod
  module Index
    # Base class for index implementations. It provides only a method
    # for accessing the index by keys, but doesn't allow to set values
    # for keys, since the kind of a value is a collection (proxy) of
    # objects, that are indexed via given key. The returned collection
    # allows for adding and removing the indexed objects.
    #
    # The implementing classes have to provide +get+ and +set+ methods,
    # which are used to retrive and assign the values respectively.
    class Base
      include Utils
      # Sets the class this index belongs to.
      def initialize(klass)
        @klass = klass
        @unstored_map = {}
      end

      # Returns the collection of objects indexed by given +key+.
      # The key might be a direct value (such as String) or a Rod object.
      def [](key)
        unstored_object = false
        if key.is_a?(Model)
          if key.new?
            proxy = @unstored_map[key]
            unstored_object = true
          else
            # TODO #155, the problem is how to determine the name_hash,
            # when the class is generated in different module
            # key = [key.rod_id,key.class.name_hash]
            key = key.rod_id
            proxy = get(key)
          end
        else
          proxy = get(key)
        end
        if proxy.nil?
          proxy = CollectionProxy.new(0,@klass.database,nil,@klass)
        else
          unless proxy.is_a?(CollectionProxy)
            offset, count = proxy
            proxy = CollectionProxy.new(count,@klass.database,offset,@klass)
          end
        end
        if unstored_object
          key.reference_updaters << ReferenceUpdater.for_index(self)
          @unstored_map[key] = proxy
        else
          set(key,proxy)
        end
        proxy
      end

      # Copies the values from +index+ to this index.
      def copy(index)
        index.each do |key,value|
          self.set(key,value)
        end
      end

      # Moves the association between an ustored +object+ from
      # memory to the index.
      def key_persisted(object)
        proxy = @unstored_map.delete(object)
        # the update for that object has been done
        return if proxy.nil?
        # TODO #155, the problem is how to determine the name_hash,
        # when the class is generated in different module
        # key = [key.rod_id,key.class.name_hash]
        key = object.rod_id
        set(key,proxy)
      end

      class << self
        # Creats the proper instance of Index or one of its sublcasses.
        # The +path+ is the path were the index is stored, while +index+ is the previous index instance.
        # The +klass+ is the class given index belongs to.
        # Options might include class-specific options.
        def create(path,klass,options)
          options = options.dup
          type = options.delete(:index)
          case type
          when :flat
            FlatIndex.new(path,klass,options)
          when :segmented
            SegmentedIndex.new(path,klass,options)
          when :hash
            HashIndex.new(path,klass,options)
          when true
            ActiveSupport::Deprecation.
              warn("Index type 'true' is deprecated. It will be removed in ROD 0.8.0")
            FlatIndex.new(path,klass,options)
          else
            raise RodException.new("Invalid index type #{type}")
          end
        end
      end
    end # class Base
  end # module Index
end # module Rod
