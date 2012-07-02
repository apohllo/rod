$:.unshift("lib")
require 'rod'
require 'rspec/expectations'

module RodTest
end

Rod::Database::Base.development_mode = true

Rod::Native::Database.instance.open_database("tmp/generate_classes",:generate => RodTest)

user = RodTest::User[0]
user = RodTest::User.find_by_name("John")
user.should_not == nil
user.name.should == "John"
user.account.should_not == nil
user.account.should == RodTest::Account[0]
user.files.size.should == 3

account = RodTest::Account[0]
account.login.should == "john"
RodTest::User.find_all_by_account(account).size.should == 1
RodTest::User.find_all_by_account(account)[0].should == user
RodTest::User.find_by_account(account).should_not == nil
user.account.should == account

user = RodTest::User.find_by_name("Amanda")
user.should_not == nil
user.name.should == "Amanda"
user.account.should_not == nil
user.files.size.should == 5

account = RodTest::Account[1]
account.login.should == "amanda"
RodTest::User.find_by_account(account).should_not == nil
user.account.should == account

file = RodTest::UserFile[0]
file.data.should == "0 data"

RodTest::UserFile.each{|f| f.data.should_not == nil}
users = RodTest::User.find_all_by_files(file)
users.size.should == 2
users[1].should == user

Rod::Native::Database.instance.close_database
