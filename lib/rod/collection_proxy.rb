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
    def initialize(size,database,offset,klass)
      @size = size
      @original_size = size
      @database = database
      @klass = klass
      @offset = offset
      @appended = []
    end

    # Returns an object with given +index+.
    def [](index)
      return nil if index >= @size
      rod_id = id_for(index)
      if rod_id.is_a?(Model)
        rod_id
      elsif rod_id == 0
        nil
      else
        class_for(index).find_by_rod_id(rod_id)
      end
    end

    # Appends element to the end of the collection.
    def <<(element)
      if element.rod_id == 0
        @appended << [element,element.class]
      else
        @appended << [element.rod_id,element.class]
      end
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
          id = id_for(index)
          if id.is_a?(Model)
            raise IdException.new(id)
          else
            yield id
          end
        end
      else
        enum_for(:each_id)
      end
    end

    # String representation.
    def to_s
      "Proxy:[#{@size}][#{@original_size}]"
    end

    # Returns true if the collection is empty.
    def empty?
      self.count == 0
    end

    protected
    def id_for(index)
      if index >= @original_size && !@appended[index - @original_size].nil?
        @appended[index - @original_size][0]
      else
        if @klass.nil?
          @database.polymorphic_join_index(@offset,index)
        else
          @database.join_index(@offset,index)
        end
      end
    end

    def class_for(index)
      if index >= @original_size && !@appended[index - @original_size].nil?
        @appended[index - @original_size][1]
      else
        if @klass.nil?
          Model.get_class(@database.polymorphic_join_class(@offset,index))
        else
          @klass
        end
      end
    end
  end
end
