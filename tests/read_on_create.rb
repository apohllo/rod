require 'tests/structures'

puts "-- Read data while creating DB --"

def validate(index)
  struct = RodTest::MyStruct[index]
  raise "Invalid MyStruct#count #{struct.count}, should be #{index}" if struct.count != index
  raise "Missing MyStruct#your_struct" if struct.your_struct.nil?
  raise "Invalid YourStruct#counter" if struct.your_struct.counter != index
end

RodTest::Model.create_database("tmp/read_write.dat")
1000.times do |index| 
  your_struct = RodTest::YourStruct.new
  your_struct.counter = index
  your_struct.store

  my_struct = RodTest::MyStruct.new
  my_struct.count = index
  my_struct.your_struct = your_struct

  my_struct.store
end

1000.times do |index|
  validate(index)
end


RodTest::Model.close_database
