$:.unshift("lib")
require 'rod'
require 'rspec/expectations'
include RSpec::Matchers

class User < Rod::Model::Base
  database_class Rod::Native::Database
  field :name, :string
end

# This class is missing in the runtime
#class Item < Rod::Model::Base
#  database_class Rod::Native::Database
#  field :name
#end

Rod::Database::Base.development_mode = true

(lambda {Rod::Native::Database.instance.open_database("tmp/missing_class")}).
  should raise_error(Rod::DatabaseError)
