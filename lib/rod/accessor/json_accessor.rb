require_relative 'sequence_accessor'
require 'json'

module Rod
  module Accessor
    # The accessor is used to load and save string values of a particular
    # property from and to the database.
    class JsonAccessor < SequenceAccessor
      protected
      # Dump the value before string it in the database.
      def dump_value(value)
        JSON::dump(value).force_encoding(ASCII_8BIT)
      end

      # Convert back the value load from the database.
      def load_value(value)
        value.force_encoding(ASCII_8BIT)
        JSON::load(value)
      end
    end
  end
end
