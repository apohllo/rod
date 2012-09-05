$:.unshift("lib")
require 'rod'

class User < Rod::Model::Base
  database_class Rod::Native::Database
  field :name, :string, :index => true
end

Rod::Native::Database.instance.create_database("tmp/index_type_true")
user = User.new(:name => "Fred")
user.store
Rod::Native::Database.instance.close_database
