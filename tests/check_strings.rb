$:.unshift("tests")
require 'structures'
require 'validate_read_on_create'

Rod::Database::Base.development_mode = true
RodTest::Database.instance.open_database("tmp/read_write")
MAGNITUDO.times do |index|
  validate(index,RodTest::MyStruct[index])
end
RodTest::Database.instance.close_database
