$:.unshift("lib")
require 'rod'

Rod::Database.development_mode = true

class Database < Rod::Database
end

class Model < Rod::Model
  database_class Database
end

class User < Model
  field :name, :string, :index => :flat
  has_one :account, :index => :flat
  has_many :files, :index => :flat, :class_name => "UserFile"
end

class Account < Model
  field :login, :string
end

class UserFile < Model
  field :data, :string
end

Database.instance.create_database("tmp/generate_classes")

files = 10.times.map{|i| UserFile.new(:data => "#{i} data")}
files.each{|f| f.store}

account = Account.new(:login => "john")
account.store
user = User.new(:name => "John", :account => account,
                :files => [files[0],files[1],files[2]])
user.store

account = Account.new(:login => "amanda")
account.store
user = User.new(:name => "Amanda", :account => account,
                :files => [files[0],files[4],files[5],nil,files[6]])
user.store

Database.instance.close_database
