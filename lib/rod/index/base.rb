# encoding: utf-8
require 'rod/utils'

module Rod
  module Index
    # Base class for index implementations.
    class Base
      include Utils

      # Copies the values from +index+ to this index.
      def copy(index)
        index.each do |key,value|
          self[key] = value
        end
      end

      class << self
        # Creats the proper instance of Index or one of its sublcasses.
        # The +path+ is the path were the index is stored, while +index+ is the previous index instance.
        # Options might include class-specific options.
        def create(path,options)
          options = options.dup
          type = options.delete(:index)
          case type
          when :flat
            FlatIndex.new(path,options)
          when :segmented
            SegmentedIndex.new(path,options)
          when :hash
            HashIndex.new(path,options)
          else
            raise RodException.new("Invalid index type #{type}")
          end
        end
      end
    end # class Base
  end # module Index
end # module Rod
