$:.unshift("lib")
require 'rod'

Rod::Database::Base.development_mode = true
class TestDatabase < Rod::Native::Database
end

class TestClass < Rod::Model::Base
  field :test, :string
  database_class TestDatabase
end

TestDatabase.instance.create_database("tmp/class_compatibility") do
end
