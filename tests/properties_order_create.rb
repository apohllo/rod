$:.unshift("lib")
require 'rod'

class User < Rod::Model::Base
  database_class Rod::Native::Database
  field :name, :string
  field :surname, :string
end

Rod::Database::Base.development_mode = true

Rod::Native::Database.instance.create_database("tmp/properties_order") do
  user = User.new(:name => "John",:surname => "Smith")
  user.store
end

