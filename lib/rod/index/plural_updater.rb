require_relative 'updater'

module Rod
  module Index
    class PluralUpdater < Updater
      # Updates the index by inspecting the changes in the associated field of
      # the +object+.
      def update(object)
        # WARNING: plural associations with nil as value are not indexed!
        # TODO #156 think over this constraint, write specs in persistence.feature
        object.__send__(@property.name).deleted.each do |deleted|
          @index[deleted].delete(object) unless deleted.nil?
        end
        object.__send__(@property.name).added.each do |added|
          @index[added] << object unless added.nil?
        end
      end
    end
  end
end


