require File.join(File.dirname(__FILE__),'service')

module Rod
  class Exporter < Service
    # Creates new database.
    def self.create(path, classes)
      generate_c_code(path, classes)
      _create(path)
    end
  end
end
