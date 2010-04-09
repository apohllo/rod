require File.join(File.dirname(__FILE__),'service')

module Rod
  class Loader < Service
    # Opens the RO database. 
    def self.open(path, classes)
      generate_c_code(path, classes)
      _open(path)
    end
  end
end
