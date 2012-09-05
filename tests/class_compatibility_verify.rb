$:.unshift("lib")
require 'rod'

Rod::Database::Base.development_mode = true
class TestDatabase < Rod::Native::Database
end

class TestClass < Rod::Model::Base
  field :test, :integer
  database_class TestDatabase
end

begin
  TestDatabase.instance.open_database("tmp/class_compatibility")
  raise "Should raise an error"
rescue Rod::IncompatibleClass => ex
  # ok, this should be thrown
end
