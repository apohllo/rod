require_relative 'sequence_accessor'

module Rod
  module Accessor
    # The accessor is used to load and save string values of a particular
    # property from and to the database.
    class StringAccessor < SequenceAccessor
      protected
      # Dump the value before string it in the database.
      def dump_value(value)
        (value || "").encode(UTF_8)
      end

      # Convert back the value loaded from the database.
      def load_value(value)
        value.force_encoding(UTF_8)
      end
    end
  end
end
