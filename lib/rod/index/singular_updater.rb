require_relative 'updater'

module Rod
  module Index
    class SingularUpdater < Updater
      # Updates the index by inspecting the changes in the associated field of
      # the +object+.
      def update(object)
        if object.new? || object.property_changed?(@property)
          remove_old_entry(object)
          # WARNING: singular associations with nil as value are not indexed!
          # TODO #156 think over this constraint, write specs in persistence.feature
          add_new_entry(object) if object.new_value(@property)
        end
      end
    end
  end
end

