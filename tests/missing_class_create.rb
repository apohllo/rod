$:.unshift("lib")
require 'rod'

class User < Rod::Model::Base
  database_class Rod::Native::Database
  field :name, :string
end

class Item < Rod::Model::Base
  database_class Rod::Native::Database
  field :name, :string
end

Rod::Database::Base.development_mode = true

Rod::Native::Database.instance.create_database("tmp/missing_class") do
  user = User.new(:name => "John")
  user.store
  item = Item.new(:name => "hammer")
  item.store
end
