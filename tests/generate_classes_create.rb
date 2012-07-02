$:.unshift("lib")
require 'rod'
require File.join(".",File.dirname(__FILE__),"generate_classes_model")

Rod::Database::Base.development_mode = true


Database.instance.create_database("tmp/generate_classes") do

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

end
