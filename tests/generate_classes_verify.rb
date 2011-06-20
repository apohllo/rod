$:.unshift("lib")
require 'rod'
require 'rspec/expectations'

module Test
end

Rod::Database.development_mode = true

Rod::Database.instance.open_database("tmp/generate_classes",:generate => true)

user = User.find_by_name("John")
user.should_not == nil
user.name.should == "John"
user.account.should_not == nil
user.account.should == Account[0]
user.files.size.should == 3

account = Account[0]
account.login.should == "john"
User.find_all_by_account(account).size.should == 1
User.find_all_by_account(account)[0].should == user
User.find_by_account(account).should_not == nil
user.account.should == account

user = User.find_by_name("Amanda")
user.should_not == nil
user.name.should == "Amanda"
user.account.should_not == nil
user.files.size.should == 5

account = Account[1]
account.login.should == "amanda"
User.find_by_account(account).should_not == nil
user.account.should == account

file = UserFile[0]
file.data.should == "0 data"

UserFile.each{|f| f.data.should_not == nil}
users = User.find_all_by_files(file)
users.size.should == 2
users[1].should == user

Rod::Database.instance.close_database
