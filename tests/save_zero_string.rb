require 'tests/structures'

puts "-- Save structures with string containing 0 test --"
RodTest::Model.create_database("tmp/string_with_zero.rod")

struct1 = RodTest::MyStruct.new
struct1.title = "abc\0abc"
struct1.title2 = "a\0" * 30000
struct2 = RodTest::YourStruct.new
struct3 = RodTest::HisStruct.new
struct1.store
struct2.store
struct3.store
RodTest::Model.close_database
