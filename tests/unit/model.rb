require 'test/unit'
require 'tests/structures'

class ModelTest < Test::Unit::TestCase
  def setup
    Test::Model.open_database("tmp/abc.dat")
  end

  def teardown
    Test::Model.close_database()
  end

  def test_referential_integrity
    struct1 = Test::MyStruct.find_by_title("title_0")
    assert(not(struct1.nil?))
    struct2 = Test::MyStruct.find_by_title("title_0")
    assert(not(struct2.nil?))
    assert(struct1.object_id == struct2.object_id, 
      "Referential integrity not working for find_by " + 
      "#{struct1.object_id}:#{struct2.object_id}")

    struct3 = Test::YourStruct.get(0)
    assert(not(struct3.nil?)) 
    struct4 = Test::HisStruct.get(0)
    assert(not(struct4.nil?))
    assert(struct3.his_structs[0].object_id == struct4.object_id,
      "Referential integrity not working for has_many " +
      "#{struct3.his_structs[0].object_id}:#{struct4.object_id}")
  end
end
