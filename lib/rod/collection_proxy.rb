module Rod
  # This class allows for lazy fetching the objects from
  # a collection of Rod objects. It holds only a Ruby proc, which
  # called returns the object with given index.
  class CollectionProxy
    include Enumerable
    attr_reader :size
    alias count size

    # Intializes the proxy with +size+ of the collection
    # and +fetch+ block for retrieving the object from the database.
    def initialize(size,&fetch)
      @size = size
      @original_size = size
      @fetch = fetch
      @appended = []
      raise InvalidArgument.new("Cannot use proxy collection without a block!") unless block_given?
      @proxy = SimpleWeakHash.new
    end

    # Returns an object with given +index+.
    def [](index)
      return nil if index >= @size
      return @proxy[index] unless @proxy[index].nil?
      rod_id, klass = id_and_class_for(index)
      result = rod_id == 0 ? nil : klass.find_by_rod_id(rod_id)
      @proxy[index] = result
    end

    # Appends element to the end of the collection.
    def <<(rod_id_and_class)
      @appended << rod_id_and_class
      @size += 1
    end

    # Simple each implementation.
    def each
      if block_given?
        @size.times do |index|
          yield self[index]
        end
      else
        enum_for(:each)
      end
    end

    # Iterate over the rod_ids.
    def each_id
      if block_given?
        @size.times do |index|
          yield id_and_class_for(index)[0]
        end
      else
        enum_for(:each_id)
      end
    end

    # String representation.
    def to_s
      "Proxy:[#{@size}][#{@original_size}]"
    end

    protected
    def id_and_class_for(index)
      if index >= @original_size && !@appended[index - @original_size].nil?
        @appended[index - @original_size]
      else
        @fetch.call(index)
      end
    end
  end
end
