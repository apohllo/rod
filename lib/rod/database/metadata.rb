# encoding: utf-8

module Rod
  module Database
    module Metadata
      # Returns the metadata loaded from the database's metadata file.
      # Raises exception if the version of library and database are
      # not compatible.
      def load_metadata
        metadata = {}
        File.open(@path + DATABASE_FILE) do |input|
          metadata = YAML::load(input)
        end
        unless valid_version?(metadata["Rod"][:version])
          raise IncompatibleVersion.new("Incompatible versions - library #{VERSION} vs. " +
                                        "file #{metadata["Rod"][:version]}")
        end
        metadata
      end

      # Writes the metadata to the database.yml file.
      def write_metadata
        metadata = {}
        rod_data = metadata["Rod"] = {}
        rod_data[:version] = VERSION
        rod_data[:created_at] = self.metadata["Rod"][:created_at] || Time.now
        rod_data[:updated_at] = Time.now
        self.classes.each do |klass|
          metadata[klass.name] = klass.metadata
          metadata[klass.name][:count] = self.count(klass)
        end
        File.open(@path + DATABASE_FILE,"w") do |out|
          out.puts(YAML::dump(metadata))
        end
      end
    end
  end
end
