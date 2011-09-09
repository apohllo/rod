$:.unshift("lib")
require 'rod'

class User < Rod::Model
  database_class Rod::Database
  field :name, :string
  field :surname, :string
end

Rod::Database.development_mode = true

Rod::Database.instance.create_database("tmp/properties_order")
user = User.new(:name => "John",:surname => "Smith")
user.store
Rod::Database.instance.close_database

