require 'bsearch'
require 'rod/model/reference_updater'

module Rod
  # This class allows for lazy fetching the elements from
  # a collection of Rod objects.
  class CollectionProxy
    include Enumerable
    attr_reader :size, :offset
    alias count size

    # Intializes the proxy with its +size+, +database+ it is connected
    # to, the +offset+ of join elements and the +klass+ of stored
    # objects. If the klass is nil, the collection holds polymorphic
    # objects.
    def initialize(size,database,offset,klass)
      raise InvalidArgument.new("collection size",nil) if size.nil?
      @size = size
      @original_size = size
      raise InvalidArgument.new("collection database",nil) if database.nil?
      @database = database
      raise InvalidArgument.new("collection offset",nil) if offset.nil?
      @offset = offset
      @klass = klass
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
      if rod_id.is_a?(Model::Resource)
        rod_id
      elsif rod_id == 0
        nil
      else
        class_for(index).find_by_rod_id(rod_id)
      end
    end

    # Returns the size of intersection with the other collection proxy.
    # XXX this method assumes that the elements are sorted according to rod_id,
    # the collection is not polymorphic and no elements were added nor deleted.
    def intersection_size(other)
      @database.fast_intersection_size(self.offset,self.size,other.offset,other.size)
    end

    # Computes a union with the +other+ collection proxy.
    def |(other)
      # So far this optimization works only for monomorphic
      # collection proxies without added elements.
      if @klass && @added.empty?
        my_ids = self.size.times.map do |index|
          id_for(index)
        end.sort
        other_ids = other.size.times.map do |index|
          other.id_for(index)
        end.sort
        ids = []
        last_id = nil
        while(!my_ids.empty?) do
          id = my_ids.shift
          other_ids.shift if other_ids.first == id
          ids << id unless last_id == id
          last_id = id
        end
        while(!other_ids.empty?) do
          id = other_ids.shift
          ids << id unless last_id == id
          last_id = id
        end
        result = CollectionProxy.new(0,@database,0,@klass)
        ids.each{|id| result << [id,@klass]}
      else
        result = self.to_a | other.to_a
      end
      result
    end

    # Computes an intersection with the +other+ collection proxy.
    def &(other)
      # So far this optimization works only for monomorphic
      # collection proxies without added elements.
      if @klass && @added.empty?
        my_ids = self.size.times.map do |index|
          id_for(index)
        end.sort
        other_ids = other.size.times.map do |index|
          other.id_for(index)
        end.sort
        ids = []
        last_id = nil
        while(!my_ids.empty?) do
          if my_ids.first == other_ids.first
            id = my_ids.shift
            other_ids.shift
            ids << id unless last_id == id
            last_id = id
          elsif my_ids.first < other_ids.first
            my_ids.shift
          else
            other_ids.shift
          end
        end
        result = CollectionProxy.new(0,@database,0,@klass)
        ids.each{|id| result << [id,@klass]}
      else
        result = self.to_a & other.to_a
      end
      result
    end

    # Appends element to the end of the collection.
    def <<(element)
      if element.nil?
        pair = [0,NilClass]
      elsif element.is_a?(Model::Resource)
        if element.new?
          pair = [element,element.class]
        else
          pair = [element.rod_id,element.class]
        end
      else
        # Assume we have an array with direct values of rod_id and class.
        pair = element
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
      if element.new?
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

    # Removes the element at +index+ from the collection.
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

    # Clears the contents of the collection proxy.
    def clear
      @deleted = @original_size.times.to_a
      @added.clear
      @map.clear
      @size = 0
    end

    # Iterator implementation. It raises an exception when
    # the collection is modified during iteration.
    # WARNING: This is not compliant with an Array class!
    def each
      if block_given?
        @size.times do |index|
          added_size = @added.size
          deleted_size = @deleted.size
          yield self[index]
          if added_size != @added.size || deleted_size != @deleted.size
            raise "Can't modify collection during iteration!"
          end
        end
      else
        enum_for(:each)
      end
    end

    # Returns a collection of added items.
    def added
      @added.map do |id_or_object,klass|
        if id_or_object.is_a?(Model::Resource)
          id_or_object
        else
          id_or_object == 0 ? nil : klass.find_by_rod_id(id_or_object)
        end
      end
    end

    # Returns a collection of deleted items.
    def deleted
      @deleted.map do |index|
        if polymorphic?
          rod_id = @database.polymorphic_join_index(@offset,index)
          if rod_id != 0
            klass = Model::Resource.class_space.
              get(@database.polymorphic_join_class(@offset,index))
          end
        else
          klass = @klass
          rod_id = @database.join_index(@offset,index)
        end
        rod_id == 0 ? nil : klass.find_by_rod_id(rod_id)
      end
    end

    # String representation of the collection proxy. Displays only the actual
    # and the original size.
    def to_s
      "Collection:[#{@size}][#{@original_size}]"
    end

    # Returns true if the collection is empty.
    def empty?
      self.count == 0
    end

    # Saves to collection proxy into disk and returns the collection
    # proxy's +offset+.
    # If no element was added nor deleted, nothing happes.
    def save
      unless @added.empty? && @deleted.empty?
        # We cannot reuse the allocated space, since the data
        # that is copied would be destroyed.
        if polymorphic?
          offset = @database.allocate_polymorphic_join_elements(@size)
        else
          offset = @database.allocate_join_elements(@size)
        end
        pairs =
          @size.times.map do |index|
            rod_id = id_for(index)
            if rod_id.is_a?(Model::Resource)
              object = rod_id
              if object.new?
                if polymorphic?
                  object.reference_updaters <<
                    Model::ReferenceUpdater.for_plural(self,index,@database)
                else
                  object.reference_updaters <<
                    Model::ReferenceUpdater.for_plural(self,index,@database)
                end
                next
              else
                rod_id = object.rod_id
              end
            end
            [rod_id,index]
          end.compact
        if polymorphic?
          pairs.each do |rod_id,index|
            class_id = (rod_id == 0 ? 0 : class_for(index).name_hash)
            @database.set_polymorphic_join_element_id(offset,index,rod_id,class_id)
          end
        else
          pairs.each do |rod_id,index|
            @database.set_join_element_id(offset,index,rod_id)
          end
        end
        @offset = offset
        @added.clear
        @deleted.clear
        @map.clear
        @original_size = @size
      end
      @offset
    end

    protected
    # Returns true if the collection proxy is polymorphic, i.e. each
    # element in the collection might be an instance of a different class.
    def polymorphic?
      @klass.nil?
    end

    # Updates in the database the +rod_id+ of the referenced object,
    # which is stored at given +index+.
    def update_reference_id(rod_id,index)
      if polymorphic?
        class_id = object.class.name_hash
        @database.set_polymorphic_join_element_id(@offset, index, rod_id, class_id)
      else
        @database.set_join_element_id(@offset, index, rod_id)
      end
    end

    # Returns the +rod_id+ of the element for given +index+. The
    # id is taken from the DB or from in-memory map, depending
    # on the fact if the collection were modified.
    def id_for(index)
      if direct_index = @map[index]
        @added[direct_index][0]
      else
        if polymorphic?
          @database.polymorphic_join_index(@offset,lazy_index(index))
        else
          @database.join_index(@offset,lazy_index(index))
        end
      end
    end

    # Returns the +class_id+ of the element for given +index+. The
    # id is taken from the DB or from in-memory map, depending
    # on the fact if the collection were modified.
    def class_for(index)
      if polymorphic?
        if direct_index = @map[index]
          @added[direct_index][1]
        else
          Model::Resource.class_space.
            get(@database.polymorphic_join_class(@offset,lazy_index(index)))
        end
      else
        @klass
      end
    end

    # Returns the index in the database corresponding to the given
    # +index+ of the collection.
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

