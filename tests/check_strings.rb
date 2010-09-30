require 'tests/structures'
require 'tests/validate_read_on_create'

RodTest::Model.open_database("tmp/read_write.dat")
MAGNITUDO.times do |index|
  validate(index,RodTest::MyStruct[index])
end
RodTest::Model.close_database
