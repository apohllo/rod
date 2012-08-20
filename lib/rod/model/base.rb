require 'rod/constants'
require 'rod/native/collection_proxy'
require 'rod/model/resource'

module Rod
  module Model
    # A class representing a model entity.
    #
    # In order for the class to be storable it is possible to
    # include only the Resource module. This is a convenience class,
    # for those who prefer to use inheritance.
    class Base
      include Resource
    end
  end
end
