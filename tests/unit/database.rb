$:.unshift("lib")
require 'test/unit'
require 'rod'

class DatabaseTest < Test::Unit::TestCase
  def test_created_at
    database = Rod::Database.instance
    database.create_database("tmp/unit_database")
    assert(Time.now - database.metadata["Rod"][:created_at] < 10)
    database.close_database
  end

  def test_updated_at
    database = Rod::Database.instance
    database.create_database("tmp/unit_database")
    sleep(1)
    database.close_database
    database.open_database("tmp/unit_database",false)
    assert(database.metadata["Rod"][:updated_at] -
           database.metadata["Rod"][:created_at] >= 1)
    assert(database.metadata["Rod"][:updated_at] -
           database.metadata["Rod"][:created_at] < 4)
    sleep(2)
    database.close_database
    database.open_database("tmp/unit_database",false)
    assert(database.metadata["Rod"][:updated_at] -
           database.metadata["Rod"][:created_at] >= 3)
    assert(database.metadata["Rod"][:updated_at] -
           database.metadata["Rod"][:created_at] < 6)
  end
end
