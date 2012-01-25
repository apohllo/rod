$:.unshift("lib")
require 'test/unit'
require 'rod'

class DatabaseTest < Test::Unit::TestCase
  def setup
    @database = Rod::Database.instance
    @database.create_database("tmp/unit_database")
  end

  def teardown
    @database.close_database
  end

  def test_version_validity
    Rod::VERSION.sub!(/.*/,"0.1.0")
    file = "0.1.0"
    assert(@database.send(:valid_version?,file))

    Rod::VERSION.sub!(/.*/,"0.1.1")
    file = "0.1.0"
    assert !(@database.send(:valid_version?,file))

    Rod::VERSION.sub!(/.*/,"0.2.1")
    file = "0.2.0"
    assert(@database.send(:valid_version?,file))

    Rod::VERSION.sub!(/.*/,"0.2.0")
    file = "0.2.1"
    assert(!@database.send(:valid_version?,file))
  end

  def test_created_at
    assert(Time.now - @database.metadata["Rod"][:created_at] < 10)
  end

  def test_updated_at
    sleep(1)
    @database.close_database
    @database.open_database("tmp/unit_database",false)
    assert(@database.metadata["Rod"][:updated_at] -
           @database.metadata["Rod"][:created_at] >= 1)
    assert(@database.metadata["Rod"][:updated_at] -
           @database.metadata["Rod"][:created_at] < 4)
    sleep(2)
    @database.close_database
    @database.open_database("tmp/unit_database",false)
    assert(@database.metadata["Rod"][:updated_at] -
           @database.metadata["Rod"][:created_at] >= 3)
    assert(@database.metadata["Rod"][:updated_at] -
           @database.metadata["Rod"][:created_at] < 6)
  end

  def test_superclass
    @database.close_database
    @database.open_database("tmp/unit_database")
    assert(@database.metadata["Rod::StringElement"][:superclass] ==
           Rod::AbstractModel.name)
  end
end
