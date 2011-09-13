require 'rod'

class Database < Rod::Database
end

class Model < Rod::Model
  database_class Database
end

class User < Model
  field :name, :string, :index => :flat
  field :surname, :string
  field :city, :string, :index => :flat
  field :street, :string, :index => :flat
  field :number, :integer, :index => :flat
  has_one :account, :index => :flat
  has_one :mother, :class_name => "User"
  has_one :father, :class_name => "User"
  has_many :files, :index => :flat, :class_name => "UserFile"
  has_many :friends, :class_name => "User"
end

class Account < Model
  field :login, :string
  field :nick, :string
end

class UserFile < Model
  field :data, :string
  field :path, :string
end

class House < Model
  field :name, :string, :index => :hash
end
