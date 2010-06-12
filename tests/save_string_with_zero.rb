require './tests/structures'

puts "-- Save structures with string containing 0 test --"

struct1 = Test::MyStruct.new
struct1.title = "abc\0abc"
struct1.title2 = "a\0" * 30000
struct2 = Test::YourStruct.new
struct3 = Test::HisStruct.new
Test::Model.create_database("tmp/string_with_zero.rod")
struct1.store
struct2.store
struct3.store
Test::Model.close_database
