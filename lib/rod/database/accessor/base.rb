module Rod
  module Database
    module Accessor
      # This class is used to connect particular property of an object to
      # a particular database. It is needed since one property of any
      # given resource might be connected to many databasese. It abstracts
      # the data access method.
      class Base
        # Creates an accessor for the +property+ connected with the +database+.
        def initialize(property,database)
          @property = property
          @database = database
        end

        protected
        # Returns the offset of the +object+ in the database.
        def object_offset(object)
          object.rod_id - 1
        end

        # Read the value of the property of the +object+.
        def read_property(object)
          object.__send__(@property.reader)
        end

        # Assign the +value+ to the property of +object+.
        def write_property(object,value)
          object.__send__(@property.writer,value)
        end
      end
    end
  end
end
