require 'rod'

class Database < Rod::Database
end

class Model < Rod::Model
  database_class Database
end

class User < Model
  field :name, :string, :index => :hash, :cache_size => 10 * 1024 * 1024
  has_one :account, :index => :hash
  has_many :files, :index => :hash, :class_name => "UserFile"
end

class Account < Model
  field :login, :string
end

class UserFile < Model
  field :data, :string
end

