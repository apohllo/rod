$:.unshift("tests")
require 'structures'
require 'validate_read_on_create'

puts "-- Read data while creating DB --"
Rod::Database.development_mode = true


RodTest::Database.create_database("tmp/read_write") do
  my_structures = []
  MAGNITUDO.times do |index|
    your_struct = RodTest::YourStruct.new
    your_struct.counter = index
    your_struct.title = "Title_#{index}"
    your_struct.store

    my_struct = RodTest::MyStruct.new
    my_struct.count = index
    my_struct.your_struct = your_struct
    my_struct.title = "Title_#{index}"
    my_struct.title2 = "Title2_#{index}"

    my_struct.store
    my_structures << my_struct
  end

  MAGNITUDO.times do |index|
    # validate object fetched from cache
    struct = RodTest::MyStruct[index]
    validate(index,struct)
    # validate object referenced previously
    validate(index,my_structures[index])
    # validate referential integrity
    if struct.object_id != my_structures[index].object_id
      raise "Object stored and recived are different #{struct.object_id} " +
        "#{my_structures[index].object_id}"
    end
    if struct != my_structures[index]
      raise "Object stored and recived are different #{struct} " +
        "#{my_structures[index]}"
    end
  end

end