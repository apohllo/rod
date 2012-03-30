module Rod
  module Berkeley
    class CollectionProxy
      include Enumerable

      # Initializes the proxy with given Berkeley +database+.
      def initialize(database,key)
        @database = database
        @key = key
      end

      def [](value_index)
        index = 0
        begin
          @database._get(@key) do |value|
            if index == value_index
              return value
            end
            index += 1
          end
          nil
        rescue KeyMissing
          nil
        end
      end

      def |(other)
        raise "#{self.class}##{__method__} not implemented yet."
      end

      def &(other)
        raise "#{self.class}##{__method__} not implemented yet."
      end

      def <<(element)
        # TODO #207 this doesn't work for not persited objects
        rod_id = element.rod_id
        raise "Not implemented #207" if rod_id.nil? || rod_id == 0
        @database.put(@key,rod_id)
      end

      def insert(index,element)
        raise "#{self.class}##{__method__} not implemented yet."
      end

      def delete(element)
        begin
          @database.delete(@key,element)
          element
        rescue KeyMissing => ex
          nil
        end
      end

      def delete_at(index)
        raise "#{self.class}##{__method__} not implemented yet."
      end

      def clear
        raise "#{self.class}##{__method__} not implemented yet."
      end

      def each
        if block_given?
          begin
            @database._get(@key) do |value|
              yield value
            end
          rescue KeyMissing
            #ignore
            nil
          end
        else
          enum_for(:each)
        end
      end

      def to_s
        raise "#{self.class}##{__method__} not implemented yet."
      end

      def empty?
        raise "#{self.class}##{__method__} not implemented yet."
      end

      def save
        raise "#{self.class}##{__method__} not implemented yet."
      end
    end
  end
end
