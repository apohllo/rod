module Rod
  module Model
    module NameConversion
      # Converts the model +name+ to the C struct name.
      def self.struct_name_for(name)
        name.underscore.gsub(/\//,"__")
      end

      # The SHA2 digest of the resource name.
      #
      # Warning: if you dynamically create classes (via Class.new)
      # this value is random, until the class is bound with a constant!
      def name_hash
        return @name_hash unless @name_hash.nil?
        # This is not used to protect any value, only to
        # distinguish names of classes. It doesn't have to be
        # very strong agains collision attacks.
        if self.struct_name.empty?
          # The resource doesn't have a name yet.
          raise AnonymousClass.new
        else
          @name_hash = Digest::SHA2.new.hexdigest(self.struct_name).
            to_s.to_i(16) % 2 ** 32
        end
      end
    end
  end
end
