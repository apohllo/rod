$:.unshift("lib")
require 'rod'

class User < Rod::Model
  database_class Rod::Database
  field :name, :string
end

class Item < Rod::Model
  database_class Rod::Database
  field :name, :string
end

Rod::Database.development_mode = true

Rod::Database.instance.create_database("tmp/missing_class")
user = User.new(:name => "John")
user.store
item = Item.new(:name => "hammer")
item.store
Rod::Database.instance.close_database
