require 'tests/structures'

puts "-- Load sample structures test --"

Test::Model.open_database("tmp/abc.dat")
Test::Model.print_layout
puts Test::MyStruct.count
puts Test::YourStruct.count
puts Test::HisStruct.count
index = 0
Test::MyStruct.each do |object|
    index += 1
      puts index if index % 1000 == 0
        object.to_s
end
Test::YourStruct.each do |object|
    object.to_s
end

puts Test::MyStruct.find_by_title("title_10")

Test::Model.close_database
