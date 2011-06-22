require 'rod'

class Database < Rod::Database
end

class Model < Rod::Model
  database_class Database
end

class User < Model
  field :name, :string, :index => :flat
  field :surname, :string
  has_one :account, :index => :flat
  has_many :files, :index => :flat, :class_name => "UserFile"
end

class Account < Model
  field :login, :string
end

class UserFile < Model
  field :data, :string
end
