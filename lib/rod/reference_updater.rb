require 'rod/exception'

module Rod
  # This class provides the set of reference updaters, that is objects
  # used to break down the process of data storage into separate steps.
  # If there is an object A which reference object B, there might be two
  # cases: object A is stored *before* object B is stored or *after* the object
  # B is stored. In the first case, the id of the object B is not know, so
  # it might be updated only after the object is stored. If the object B
  # stored the reference to object A (to update its reference to the object
  # B), then the object A could not be GC'ed until object B is stored.
  # For large nets of objects, this would result in large non-GCable collections
  # of objects. The reference updater splits the reference of object B to A
  # and allows for GC of A, even thou B is not yet stored.
  class ReferenceUpdater
    # Singular reference updater holds the +rod_id+ and +class_id+ of the
    # object that has to be updated and the name of the
    # +property+ of the reference to be updated.
    class SingularUpdater
      def initialize(database,rod_id,class_id,property)
        @database = database
        @rod_id = rod_id
        @class_id = class_id
        @property = property
      end

      # Updates the id of the referenced +object+.
      def update(object)
        referee = Model.get_class(@class_id).find_by_rod_id(@rod_id)
        referee.update_singular_association(@property,object)
      end
    end

    # Plural reference updater holds the +collection+ proxy
    # that includes the reference to be updated and its +index+
    # within that collection.
    class PluralUpdater
      def initialize(database,collection,index)
        @database = database
        @collection = collection
        @index = index
      end

      # Updates the id of the referenced +object+.
      def update(object)
        @collection.send(:update_reference_id,object.rod_id,@index)
      end
    end

    # This updater is used when there is an index of Rod objects
    # and one of its keys is an object which is not yet stored.
    # The key of the index is set to the rod_id, when the object
    # is stored.
    class IndexUpdater
      # The updater is initialized with the +index+ to be updated.
      def initialize(index)
        @index = index
      end

      # Updates the index by providing the object with the updated +rod_id+.
      def update(object)
        @index.key_persisted(object)
      end
    end

    # Creates singular reference updater of for the +property+
    # of the +object+ that belongs to the +database+.
    def self.for_singular(object,property,database)
      SingularUpdater.new(database,object.rod_id,object.class.name_hash,property)
    end

    # Creates plural reference updater for given
    # +collection+ proxy with given +index+.
    def self.for_plural(collection,index,database)
      PluralUpdater.new(database,collection,index)
    end

    # Creates reference updater for an index. It is used
    # when the indexed plural association includes objects
    # that are not yet persisted.
    def self.for_index(index)
      IndexUpdater.new(index)
    end
  end
end
