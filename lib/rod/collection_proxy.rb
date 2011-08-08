require 'bsearch'

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
      #@commands = []
      @added = []
      @deleted = []
      @map = {}
    end

    # Returns an object with given +index+.
    # The +index+ have to be positive and smaller from the collection size.
    # Otherwise +nil+ is returned.
    def [](index)
      return nil if index >= @size || index < 0
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
        pair = [element,element.class]
      else
        pair = [element.rod_id,element.class]
      end
      index = @size
      @map[index] = @added.size
      @added << pair
      #@commands << [:append, pair]
      @size += 1
    end

    # Inserts the +element+ at given +index+.
    # So far the +index+ has to be positive, smaller or equal to size
    # and only one pair of values is accepted. If these assumptions
    # are not met, nil is returned.
    def insert(index,element)
      return nil if index < 0 || index > @size
      if element.rod_id == 0
        pair = [element,element.class]
      else
        pair = [element.rod_id,element.class]
      end
      @map.keys.sort.reverse.each do |key|
        if key >= index
          value = @map.delete(key)
          @map[key+1] = value
        end
      end
      @map[index] = @added.size
      @added << pair
      #@commands << [:insert,pair]
      @size += 1
      self
    end

    # Removes the +element+ from the collection.
    def delete(element)
      indices = []
      self.each.with_index{|e,i| indices << i if e == element}
      if indices.empty?
        if block_given?
          return yield
        else
          return nil
        end
      end
      #@commands << [:delete,indices]
      indices.each.with_index do |index,offset|
        self.delete_at(index-offset)
      end
      element
    end

    # Removes the element at +index+ from the colelction.
    # So far the +index+ has to be positive.
    def delete_at(index)
      return nil if index >= @size || index < 0
      element = self[index]
      if direct_index = @map[index]
        @added.delete_at(direct_index)
        @map.delete(index)
        @map.keys.sort.each do |key|
          if key > index
            value = @map.delete(key)
            value -= 1 if value > direct_index
            @map[key-1] = value
          else
            if (value = @map[key]) > direct_index
              @map[key] -= 1
            end
          end
        end
      else
        lazy_index = lazy_index(index)
        position = @deleted.bsearch_upper_boundary{|e| e <=> lazy_index }
        @deleted.insert(position,lazy_index)
        @map.keys.sort.each do |key|
          if key > index
            @map[key-1] = @map.delete(key)
          end
        end
      end
      #@commands << [:delete,[index]]
      @size -= 1
      element
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
      if direct_index = @map[index]
        @added[direct_index][0]
      else
        if @klass.nil?
          @database.polymorphic_join_index(@offset,lazy_index(index))
        else
          @database.join_index(@offset,lazy_index(index))
        end
      end
    end

    def class_for(index)
      if direct_index = @map[index]
        @added[direct_index][1]
      else
        if @klass.nil?
          Model.get_class(@database.polymorphic_join_class(@offset,lazy_index(index)))
        else
          @klass
        end
      end
    end

    def lazy_index(index)
      index -= @map.keys.select{|e| e < index}.size
      result = 0
      @deleted.each do |deleted_index|
        if deleted_index - result > index
          return result + index
        else
          index -= deleted_index - result
          result = deleted_index + 1
        end
      end
      result + index
    end
  end
end
