$:.unshift("tests")
require 'structures'

puts "-- Save sample structures test --"
Rod::Database::Base.development_mode = true

RodTest::Database.instance.create_database("tmp/simple_test") do
  #MAGNITUDE = 100000
  MAGNITUDE = 50

  his = []
  (MAGNITUDE * 10).times do |index|
    his[index] = RodTest::HisStruct.new
    his[index].inde = index
  end

  your_structure = []
  (MAGNITUDE * 1).times do |index|
    structure = your_structure[index] = RodTest::YourStruct.new
    structure.counter = 10
    structure.his_structs = his[index*10...(index+1)*10]
  end

  my_structure = []
  (MAGNITUDE * 1).times do |index|
    structure = my_structure[index] = RodTest::MyStruct.new
    structure.count = 10 * index
    structure.precision = 0.1 * index
    structure.identifier = index
    structure.your_struct = your_structure[index]
    structure.title = "title_#{index}"
    structure.title2 = "title2_#{index}"
    structure.body = "body_#{index}"
  end

  RodTest::Database.instance.print_layout
  my_structure.each_with_index do |structure,index|
    begin
      structure.store
    rescue Exception => e
      puts e
      raise
    end
  end
  your_structure.each{|y| y.store}
  his.each{|h| h.store}
  RodTest::Database.instance.print_layout
end
