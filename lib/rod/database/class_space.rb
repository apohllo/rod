# encoding: utf-8

module Rod
  module Database
    module ClassSpace
      # Special classes used by the database.
      def special_classes
        [Model::JoinElement, Model::PolymorphicJoinElement, Model::StringElement]
      end

      # Returns true if the class is one of speciall classes
      # (JoinElement, PolymorphicJoinElement, StringElement).
      def special_class?(klass)
        self.special_classes.include?(klass)
      end

      # Returns collected classes tied with this DB.
      def classes
        @classes.sort{|c1,c2| c1.to_s <=> c2.to_s}
      end

      # Adds the +klass+ to the set of classes linked with this database.
      def add_class(klass)
        @classes << klass unless @classes.include?(klass)
      end

      # Remove the +klass+ from the set of classes linked with this database.
      def remove_class(klass)
        unless @classes.include?(klass)
          raise DatabaseError.new("Class #{klass} is not linked with #{self}!")
        end
        @classes.delete(klass)
      end
    end
  end
end
