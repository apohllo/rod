$:.unshift("lib")
require 'rod'

Rod::Database.development_mode = true
class TestDatabase < Rod::Database
end

class TestClass < Rod::Model
  field :test, :integer
  database_class TestDatabase
end

begin
  TestDatabase.instance.open_database("tmp/class_compatibility")
  raise "Should raise an error"
rescue Rod::IncompatibleVersion => ex
  # ok, this should be thrown
end
