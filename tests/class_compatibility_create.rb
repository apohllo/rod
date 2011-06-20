$:.unshift("lib")
require 'rod'

Rod::Database.development_mode = true
class TestDatabase < Rod::Database
end

class TestClass < Rod::Model
  field :test, :string
  database_class TestDatabase
end

TestDatabase.instance.create_database("tmp/class_compatibility")
TestDatabase.instance.close_database
