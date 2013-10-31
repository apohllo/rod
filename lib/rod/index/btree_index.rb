# encoding: utf-8
require 'rod/index/berkeley_index'

module Rod
  module Index
    # This implementation of index is based on the
    # Berkeley DB Btree access method.
    class BtreeIndex < BerkeleyIndex
      # The class given index is associated with.
      attr_reader :klass

      # Opens the index - initializes the index C structures
      # and the cache.
      # Options:
      # * +:truncate+ - clears the contents of the index
      # * +:create+ - creates the index if it doesn't exist
      # * +:cache_size+ - the cache size in bytes (must be power of 2)
      def open(options={})
        raise RodException.new("The index #{@path} is already opened!") if opened?
        options[:type] = :btree
        _open(@path, options)
        @opened = true
      end
    end
  end
end
