require 'tests/structures'

puts "-- Load structures with string containing 0 test --"

RodTest::Model.open_database("tmp/string_with_zero.rod")
structs = []
RodTest::MyStruct.each{|e| structs << e}
if structs[0].title != "abc\0abc"
  raise "TestFailed: #{struct.title}" 
end
if structs[0].title2 != "a\0" * 30000
  raise "TestFailed: 'a\\0' * 30000"
end
puts "Test passed."
RodTest::Model.close_database
