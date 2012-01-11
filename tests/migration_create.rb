$:.unshift("lib")
require 'rod'
require File.join(".",File.dirname(__FILE__),"migration_model1")

Rod::Database.development_mode = true

FileUtils.rm_rf("tmp/migration")
Database.create_database("tmp/migration") do

  count = (ARGV[0] || 10).to_i
  puts "Count in migration test: #{count}"

  files = count.times.map{|i| UserFile.new(:data => "#{i} data")}
  files.each{|f| f.store}

  users = []
  count.times do |index|
    account = Account.new(:login => "john#{index}",
                          :nick => "j#{index}")
    account.store
    user1 = User.new(:name => "John#{index}",
                     :surname => "Smith#{index}",
                     :city => "City#{index}",
                     :street => "Street#{index}",
                     :number => index,
                     :account => account,
                     :mother => users[index-1],
                     :father => users[index-2],
                     :friends => [users[index-3],users[index-4]],
                     :files => [files[index],files[index + 1],files[index + 2]])
    user1.store

    account = Account.new(:login => "amanda#{index}",
                          :nick => "a#{index}")
    account.store
    user2 = User.new(:name => "Amanda#{index}",
                     :surname => "Amanda#{index}",
                     :city => "Bigcity#{index}",
                     :street => "Small street#{index}",
                     :number => index,
                     :account => account,
                     :mother => users[index-1],
                     :father => users[index-2],
                     :friends => [users[index-5],users[index-6]],
                     :files => [files[index],files[index+4],files[index+5],
                       nil,files[index+6]])
    user2.store
    users << user1
    users << user2
  end

  house = House.new(:name => "cottage house")
  house.store

end
