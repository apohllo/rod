$:.unshift("tests")
require 'test/unit'
require 'structures'

class ModelTest < Test::Unit::TestCase
  def setup
    RodTest::Model.open_database("tmp/abc.dat")
  end

  def teardown
    RodTest::Model.close_database()
  end

  def test_referential_integrity
    struct1 = RodTest::MyStruct.find_by_title("title_0")
    assert(not(struct1.nil?))
    struct2 = RodTest::MyStruct.find_by_title("title_0")
    assert(not(struct2.nil?))
    assert(struct1.object_id == struct2.object_id,
      "Referential integrity not working for find_by " +
      "#{struct1.object_id}:#{struct2.object_id}")

    struct3 = RodTest::YourStruct.get(0)
    assert(not(struct3.nil?))
    struct4 = RodTest::HisStruct.get(0)
    assert(not(struct4.nil?))
    assert(struct3.his_structs[0].object_id == struct4.object_id,
      "Referential integrity not working for has_many " +
      "#{struct3.his_structs[0].object_id}:#{struct4.object_id}")
  end

  def test_print_system_error
    RodTest::MyStruct.print_system_error
  end
end
