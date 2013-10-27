require_relative 'updater'

module Rod
  module Index
    class FieldUpdater < Updater
      # Updates the index by inspecting the changes in the associated field of
      # the +object+.
      def update(object)
        if object.new? #|| object.property_changed?(@property)
          remove_old_entry(object)
          add_new_entry(object)
        end
      end
    end
  end
end
