require 'rod'

class Database < Rod::Database
end

class Model < Rod::Model
  database_class Database
end

class User < Model
  # present
  field :name, :string, :index => :flat

  # removed
  # field :surname, :string

  # changed: index flat -> segmented
  field :city, :string, :index => :segmented

  # changed: index flat -> hash
  field :street, :string, :index => :hash

  # changed: index flat -> nil
  field :number, :integer

  # added
  field :age, :integer

  # present
  has_one :account, :index => :flat

  # removed
  # has_one :mother, :class_name => "User"

  # removed
  # has_one :father, :class_name => "User"

  # added
  has_one :file, :class_name => "UserFile"

  # present
  has_many :files, :index => :flat, :class_name => "UserFile"

  # added
  has_many :accounts, :index => :flat

  # removed
  # has_many :friends, :class_name => "User"
end

class Account < Model
  # changed: index added
  field :login, :string, :index => :flat

  # removed
  # field :nick, :string

  # added
  field :password, :string
end

class UserFile < Model
  # present
  field :data, :string

  # removed
  # field :path, :string

  # added
  field :name, :string, :index => :flat
end

# The whole class is the same.
class House < Model
  field :name, :string, :index => :hash
end
