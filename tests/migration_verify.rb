$:.unshift("lib")
require 'rod'
require 'rspec/expectations'
require File.join(".",File.dirname(__FILE__),"migration_model2")

Rod::Database.development_mode = true

Database.instance.open_database("tmp/migration")

user = User[0]
user.should_not == nil
user = User.find_by_name("John")
user.should_not == nil
user.name.should == "John"
user.age.should == 0
user.account.should_not == nil
user.account.should == Account[0]
user.files.size.should == 3
user.accounts.size.should == 1
user.accounts[0].should == user.account

account = Account[0]
account.login.should == "john"
account.password.should == ""
User.find_all_by_account(account).size.should == 1
User.find_all_by_account(account)[0].should == user
User.find_by_account(account).should_not == nil
user.account.should == account

user = User.find_by_name("Amanda")
user.should_not == nil
user.name.should == "Amanda"
user.age.should == 0
user.account.should_not == nil
user.files.size.should == 5
user.accounts.size.should == 1
user.accounts[0].should == user.account

account = Account[1]
account.login.should == "amanda"
account.password.should == ""
User.find_by_account(account).should_not == nil
user.account.should == account

file = UserFile[0]
file.data.should == "0 data"

UserFile.each do |file|
  file.data.should_not == nil
  file.name.should == ""
end
users = User.find_all_by_files(file)
users.size.should == 2
users[1].should == user

Database.instance.close_database
