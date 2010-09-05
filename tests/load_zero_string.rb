require 'tests/structures'

puts "-- Load structures with string containing 0 test --"

RodTest::Model.open_database("tmp/string_with_zero.rod")
element = RodTest::MyStruct[0]
if element.title != "abc\0abc"
  raise "TestFailed: #{element.title}" 
end
if element.title2 != "a\0" * 30000
  puts "#{element.title2.size} 0..5:'#{element.title2[0..5]}' "
  puts "-5..-1:'#{element.title2[-5..-1]}'"
  raise "TestFailed: 'a\\0' * 30000"
end
puts "Test passed."
RodTest::Model.close_database
