# encoding: utf-8
require 'rod/index/base'

module Rod
  module Index
    # Class implementing segmented index, i.e. an index which allows for
    # lazy loading of its pieces.
    class SegmentedIndex < Base
      # Default number of buckats.
      BUCKETS_COUNT = 1001
      # Creats the index with given +path+, with the previous +index+ instance
      # and the following +options+:
      # * +:buckets_count+ - the number of buckets.
      def initialize(path,klass,options={:buckets_count => BUCKETS_COUNT})
        super(klass)
        @path = path + "_idx/"
        @buckets_count = options[:buckets_count] || BUCKETS_COUNT
        @buckets_ceil = Math::log2(@buckets_count).ceil
        @buckets = {}
      end

      # Stores the index at @path. Assumes the path exists.
      def save
        unless File.exist?(@path)
          Dir.mkdir(@path)
        end
        @buckets.each do |bucket_number,hash|
          File.open(path_for(bucket_number),"w") do |out|
            proxy_index = {}
            hash.each{|k,col| proxy_index[k] = [col.offset,col.size]}
            out.puts(Marshal.dump(proxy_index))
          end
        end
      end

      # Destroys the index (removes it from the disk completely).
      def destroy
        remove_files(@path + "*")
      end

      def each
        if block_given?
          @buckets.each do |bucket_number,hash|
            hash.each_key do |key|
              yield key, self[key]
            end
          end
        else
          enum_for(:each)
        end
      end

      protected
      def get(key)
        bucket_number = bucket_for(key)
        load_bucket(bucket_number) unless @buckets[bucket_number]
        @buckets[bucket_number][key]
      end

      def set(key,value)
        bucket_number = bucket_for(key)
        load_bucket(bucket_number) unless @buckets[bucket_number]
        @buckets[bucket_number][key] = value
      end

      def bucket_for(key)
        case key
        when NilClass
          1 % @buckets_count
        when TrueClass
          2 % @buckets_count
        when FalseClass
          3 % @buckets_count
        when String
          key.sum(@buckets_ceil) % @buckets_count
        when Integer
          key % @buckets_count
        when Float
          (key.numerator - key.denominator) % @buckets_count
        else
          raise RodException.new("Object of type '#{key.class}' not supported as a key of segmented index!")
        end
      end

      def path_for(bucket_number)
        "#{@path}#{bucket_number}.idx"
      end

      def load_bucket(bucket_number)
        if File.exist?(path_for(bucket_number))
          File.open(path_for(bucket_number)) do |input|
            @buckets[bucket_number] = Marshal.load(input)
          end
        else
          @buckets[bucket_number] = {}
        end
      end
    end # class SegmentedIndex
  end # module Index
end # module Rod
