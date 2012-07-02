$:.unshift("lib")
require 'test/unit'
require 'rod'

class AbstractDatabaseTest < Test::Unit::TestCase
  def test_canonicalize_path
    db = Rod::Database::Base.instance
    path = "/abc"
    assert_equal(db.send(:canonicalize_path,path),path + "/")
    path = "/abc/"
    assert_equal(db.send(:canonicalize_path,path),path)
  end
end
