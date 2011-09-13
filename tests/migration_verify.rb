$:.unshift("lib")
require 'rod'
require 'rspec/expectations'
require File.join(".",File.dirname(__FILE__),"migration_model2")

Rod::Database.development_mode = true

Database.instance.open_database("tmp/migration")

count = (ARGV[0] || 10).to_i
key_count = 0
User.index_for(:street,:index => :hash).each do |key,proxy|
  key_count += 1
  proxy.to_a.should == User.find_all_by_street(key).to_a
end
key_count.should > 0
count.times do |index|
  user1 = User[index*2]
  user1.should_not == nil
  user1.name.should == "John#{index}"
  user = User.find_by_name("John#{index}")
  user.should == user1
  users = User.find_all_by_city("City#{index}")
  users.size.should == 0
  users = User.find_all_by_city("Small town#{index}")
  users.size.should == 1
  users[0].should == user1
  users = User.find_all_by_street("Street#{index}")
  users.size.should == 1
  users[0].should == user1
  user1.name.should == "John#{index}"
  user1.age.should == index
  user1.account.should_not == nil
  user1.account.should == Account[index * 2]
  user1.account.login.should == "john#{index}"
  user1.account.password.should == "pass#{index * 2}"
  User.find_all_by_account(user1.account).size.should == 1
  User.find_all_by_account(user1.account)[0].should == user
  User.find_by_account(user1.account).should_not == nil
  user1.files.size.should == 3
  user1.files[0].data.should == "#{index} data"
  user1.files[0].name.should == "file#{index}"
  user1.accounts.size.should == 1
  user1.accounts[0].should == user1.account

  user2 = User[index*2+1]
  user2.should_not == nil
  user = User.find_by_name("Amanda#{index}")
  user.should == user2
  user = User.find_by_city("Bigcity#{index}")
  #user.should == user2
  user = User.find_by_street("Small street#{index}")
  user.should == user2
  user2.name.should == "Amanda#{index}"
  user2.age.should == index * 2
  user2.account.should_not == nil
  user2.account.should == Account[index * 2 + 1]
  user2.account.password.should == "pass#{index * 2 + 1}"
  User.find_by_account(user2.account).should == user2
  user2.files.size.should == 5
  user2.files[0].data.should == "#{index} data"
  user2.files[0].name.should == "file#{index}"
  user2.files[3].data.should == nil unless user2.files[3].nil?
  user2.accounts.size.should == 2
  user2.accounts[0].should == user1.account
  user2.accounts[1].should == user2.account
end


UserFile.each.with_index do |file,index|
  file.data.should_not == nil
  file.data.should == "#{index} data"
  file.name.should_not == nil
  file.name.should == "file#{index}"
end

users = User.find_all_by_files(UserFile[0])
users.size.should == 2
users[0].should == User[0]
users[1].should == User[1]

house = House.find_by_name("cottage house")
house.should_not == nil
house.name.should == "cottage house"

Database.instance.close_database
