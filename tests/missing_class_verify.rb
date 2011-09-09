$:.unshift("lib")
require 'rod'
require 'rspec/expectations'
include RSpec::Matchers

class User < Rod::Model
  database_class Rod::Database
  field :name, :string
end

# This class is missing in the runtime
#class Item < Rod::Model
#  database_class Rod::Database
#  field :name
#end

Rod::Database.development_mode = true

(lambda {Rod::Database.instance.open_database("tmp/missing_class")}).
  should raise_error(Rod::DatabaseError)
