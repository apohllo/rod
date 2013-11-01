# encoding: utf-8
require 'rod/index/berkeley_index'

module Rod
  module Index
    # This implementation of index is based on the
    # Berkeley DB Btree access method.
    class BtreeIndex < BerkeleyIndex
      # Initializes the index with +path+, +class+ and +options+.
      #
      # Options:
      # * +:proxy_factor+ - factory used to create collection proxies
      #   (Rod::Berkeley::CollectionProxy by default).
      # * +:order+ - lambda used to compare and sort the keys, by default
      #   it's nil, which means that the keys have alphabetic order. The
      #   returned value must reflect the semantics of <=> Ruby operator
      #   (i.e. -1, 0, 1).
      def initialize(path,klass,options={})
        @key_comparison_lambda = options[:order]
        super
      end

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

      protected
      # Compares +key_a+ to +key_b+ according to the user-defined comparison
      # function.
      def compare_keys(key_a,key_b)
        @key_comparison_lambda.call(Marshal.load(key_a),Marshal.load(key_b))
      end
    end
  end
end
