module Rod
  module Model
    module NameConversion
      # The SHA2 digest of the resource name.
      #
      # Warning: if you dynamically create classes (via Class.new)
      # this value is random, until the class is bound with a constant!
      def self.name_hash(resource)
        # This is not used to protect any value, only to
        # distinguish names of classes. It doesn't have to be
        # very strong agains collision attacks.
        if resource_name(resource).empty?
          # The resource doesn't have a name yet.
          raise AnonymousClass.new
        else
          Digest::SHA2.new.hexdigest(resource_name(resource)).
            to_s.to_i(16) % (2 ** 32)
        end
      end

      # Converts the name of the resource to a simple form.
      def self.resource_name(resource)
        if resource.to_s =~ /^\#/
          ""
        else
          Utils.struct_name_for(resource.to_s)
        end
      end
    end
  end
end
