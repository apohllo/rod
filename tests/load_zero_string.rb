require 'tests/structures'

puts "-- Load structures with string containing 0 test --"

Test::Model.open_database("tmp/string_with_zero.rod")
structs = []
Test::MyStruct.each{|e| structs << e}
if structs[0].title != "abc\0abc"
  raise "TestFailed: #{struct.title}" 
end
if structs[0].title2 != "a\0" * 30000
  raise "TestFailed: 'a\\0' * 30000"
end
puts "Test passed."
Test::Model.close_database
