module Rod
  # This class allows for lazy fetching the objects from
  # a collection of Rod objects. It holds only a Ruby proc, which
  # called returns the object with given index.
  class CollectionProxy
    include Enumerable

    # Intializes the proxy with +size+ of the collection
    # and +fetch+ block for retrieving the object from the database.
    def initialize(size,&fetch)
      @size = size
      @fetch = fetch
      raise InvalidArgument.new("Cannot use proxy collection without a block!") unless block_given?
      @proxy = SimpleWeakHash.new
    end

    # Returns an object with given +index+.
    def [](index)
      return nil if index >= @size
      return @proxy[index] unless @proxy[index].nil?
      result = @fetch.call(index)
      @proxy[index] = result
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
  end
end
