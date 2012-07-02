require 'singleton'

module Rod
  module Model
    class Cache
      class InternalMap
        include Singleton
        attr_reader :mutex

        def initialize
          @mutex = Mutex.new
          @object_to_caches = Hash.new{|h,v| h[v] = []}
          @finalizer = lambda do |object_id|
            @object_to_caches[object_id].each do |cache,key|
              cache.delete(key)
            end
            @object_to_caches.delete(object_id)
          end
        end

        def register(value,key,cache)
          @object_to_caches[value.object_id] << [cache,key]
          ObjectSpace.define_finalizer(value,@finalizer)
        end
      end

      def initialize
        @map = {}
        @direct_values_map = {}
      end

      def [](key)
        if @direct_values_map[key]
          return @map[key]
        else
          value_id = nil
          value_id = @map[key]
          return value_id if value_id.nil?
          begin
            return ObjectSpace._id2ref(value_id)
          rescue RangeError
            @map.delete(key)
            return nil
          end
        end
      end

      def []=(key,value)
        @direct_values_map.delete(key)
        case value
        when Fixnum, Symbol, FalseClass, TrueClass, NilClass
          @map[key] = value
          @direct_values_map[key] = true
        else
          @map[key] = value.object_id
          InternalMap.instance.register(value,key,@map)
        end
      end

      def clear
        @map.clear
        @direct_values_map.clear
      end

      def delete(key)
        @map.delete(key)
        @direct_values_map.delete(key)
      end

      def each
        if block_given?
          @map.each do |key,value|
            begin
              yield self[key]
            end
          end
        else
          enum_for(:each)
        end
      end
    end
  end
end
