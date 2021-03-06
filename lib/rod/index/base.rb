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

      # The path of the index.
      attr_reader :path

      # Creates new index on the given +path+ and configured with
      # +klass+ it belongs to. The +proxy_factory+ is used to
      # create collection proxies for keys with many values.
      def initialize(path,klass,proxy_factory=CollectionProxy)
        @path = path
        @klass = klass
        @proxy_factory = proxy_factory
        @unstored_map = {}
      end

      # Returns the collection of objects indexed by given +key+.
      # The key might be a direct value (such as String) or a Rod object.
      def [](key)
        unstored_object = false
        if key.is_a?(resouce = Model::Resource)
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
          proxy = empty_collection_proxy(key)
        else
          if Array === proxy
            offset, count = proxy
            proxy = @proxy_factory.new(count,@klass.database,offset,@klass)
          end
        end
        if unstored_object
          key.reference_updaters << Model::ReferenceUpdater.for_index(self)
          @unstored_map[key] = proxy
        else
          set(key,proxy)
        end
        proxy
      end

      # Copies the values from +index+ to this index.
      def copy(index)
        index.each.with_index do |key_value,position|
          # TODO #206 this doesn't work for hash
          self.set(key_value[0],key_value[1])
          # TODO #182 implement size for index
          # report_progress(position,index.size) if $ROD_DEBUG
        end
      end

      # Rebuilds the index. The index is destroyed and then it
      # is populated with all objects of the class.
      def rebuild
        self.destroy
        @klass.each.with_index do |object,position|
          self[object.send(property.name)] << object
          report_progress(position,@klass.count) if $ROD_DEBUG
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

      # The default representation shows the index class and path.
      def to_s
        "#{self.class}@#{@path}"
      end

      protected

      # Returns an empty collection proxy. Might be changed
      # in subclasses to provie index-specific collection proxies.
      def empty_collection_proxy(key)
        proxy = @proxy_factory.new(0,@klass.database,0,@klass)
      end

      class << self
        # Creats the proper instance of Index or one of its sublcasses.
        # The +path+ is the path were the index is stored, while +index+
        # is the previous index instance.
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
          when :btree
            BtreeIndex.new(path,klass,options)
          when true
            ActiveSupport::Deprecation.
              warn("Index type 'true' is deprecated. It will be removed in ROD 0.8.0")
            FlatIndex.new(path,klass,options)
          else
            raise RodException.new("Invalid index type '#{type}'")
          end
        end
      end
    end # class Base
  end # module Index
end # module Rod
