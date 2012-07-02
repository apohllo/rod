module Rod
  module Database
    # The methods related to the database that are extended into Resource.
    module ClassMethods
      # The database class is configured with the call to
      # macro-style function +database_class+. This information
      # is inherited, so it have to be defined only for the
      # root-class of the model (if such a class exists).
      def database
        return @database unless @database.nil?
        @database = superclass.database
      rescue NoMethodError
        raise MissingDatabase.new(self)
      end

      protected
      # The pointer to the mmaped table of C structs.
      def rod_pointer
        @rod_pointer
      end

      # Writer for the pointer to the mmaped table of C structs.
      def rod_pointer=(value)
        @rod_pointer = value
      end

      # Add self to the database it is linked to.
      def add_to_database
        self.database.add_class(self)
      end

      # A macro-style function used to link the model with specific
      # database class. See notes on Rod::Database::Base for further
      # information why this is needed.
      def database_class(klass)
        unless @database.nil?
          @database.remove_class(self)
        end
        @database = klass.instance
        self.add_to_database
      end
    end
  end
end
