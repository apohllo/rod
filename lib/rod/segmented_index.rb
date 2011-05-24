module Rod
  # Class implementing segmented index, i.e. an index which allows for
  # lazy loading of its pieces.
  class SegmentedIndex
    # Creats the index with given +path+ and number of buckets (+buckets_count+).
    def initialize(path,buckets_count=1001)
      @path = path
      @buckets_count = buckets_count
      @buckets_ceil = Math::log2(buckets_count).ceil
      @buckets = {}
    end

    # Stores the index at @path. Assumes the path exists.
    def save
      @buckets.each do |bucket_number,hash|
        File.open(path_for(bucket_number),"w") do |out|
          out.puts(Marshal.dump(hash))
        end
      end
    end

    # Return value for the key.
    def [](key)
      bucket_number = bucket_for(key)
      unless @buckets[bucket_number]
        if File.exist?(path_for(bucket_number))
          File.open(path_for(bucket_number)) do |input|
            @buckets[bucket_number] = Marshal.load(input)
          end
        else
          @buckets[bucket_number] = {}
        end
      end
      @buckets[bucket_number][key]
    end

    # Set the value for the key.
    def []=(key,value)
      bucket_number = bucket_for(key)
      @buckets[bucket_number] = {} unless @buckets[bucket_number]
      @buckets[bucket_number][key] = value
    end

    protected
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
  end
end
