require 'rod'

class Database < Rod::Database
end

class Model < Rod::Model
  database_class Database
end

class User < Model
  field :name, :string, :index => :flat
  field :age, :integer
  has_one :account, :index => :flat
  has_many :files, :index => :flat, :class_name => "UserFile"
  has_many :accounts, :index => :flat
end

class Account < Model
  field :login, :string
  field :password, :string
end

class UserFile < Model
  field :data, :string
  field :name, :string, :index => :flat
end

