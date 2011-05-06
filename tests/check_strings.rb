$:.unshift("tests")
require 'structures'
require 'validate_read_on_create'

RodTest::Database.instance.open_database("tmp/read_write.dat")
MAGNITUDO.times do |index|
  validate(index,RodTest::MyStruct[index])
end
RodTest::Database.instance.close_database
