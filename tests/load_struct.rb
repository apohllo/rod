$:.unshift("tests")
require 'structures'

puts "-- Load sample structures test --"

Rod::Database::Base.development_mode = true
RodTest::Database.instance.open_database("tmp/abc")
RodTest::Database.instance.print_layout
puts RodTest::MyStruct.count
puts RodTest::YourStruct.count
puts RodTest::HisStruct.count
index = 0
RodTest::MyStruct.each do |object|
  index += 1
  puts index if index % 1000 == 0
  object.to_s
end
RodTest::YourStruct.each do |object|
    object.to_s
end

puts RodTest::MyStruct.find_by_title("title_10")

RodTest::Database.instance.close_database
