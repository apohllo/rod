require_relative 'sequence_accessor'

module Rod
  module Database
    module Accessor
      # The accessor is used to load and save string values of a particular
      # property from and to the database.
      class ObjectAccessor < SequenceAccessor
        protected
        # Dump the value before string it in the database.
        def dump_value(value)
          Marshal::dump(value).force_encoding(ASCII_8BIT)
        end

        # Convert back the value load from the database.
        def load_value(value)
          value.force_encoding(ASCII_8BIT)
          Marshal::load(value)
        end
      end
    end
  end
end
