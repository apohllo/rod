$:.unshift("lib")
require 'test/unit'
require 'rod'

class ModelTest < Test::Unit::TestCase
  def test_version_validity
    database = Rod::AbstractDatabase.instance
    Rod::VERSION.sub!(/.*/,"0.1.0")
    file = "0.1.0"
    assert(database.send(:valid_version?,file))

    Rod::VERSION.sub!(/.*/,"0.1.1")
    file = "0.1.0"
    assert(not(database.send(:valid_version?,file)))

    Rod::VERSION.sub!(/.*/,"0.2.1")
    file = "0.2.0"
    assert(database.send(:valid_version?,file))
  end
end
