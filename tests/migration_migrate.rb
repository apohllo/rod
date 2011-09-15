$:.unshift("lib")
require 'rod'
require File.join(".",File.dirname(__FILE__),"migration_model2")
require 'rspec/expectations'

#$ROD_DEBUG = true
Rod::Database.development_mode = true

Database.instance.migrate_database("tmp/migration")
Database.instance.open_database("tmp/migration", :readonly => false)
Dir.glob("tmp/migration/#{Rod::BACKUP_PREFIX[0..-2]}*").to_a.size.should == 1

count = (ARGV[0] || 10).to_i
count.times do |index|
  account1 = Account[index * 2]
  account1.password = "pass#{index * 2}"
  account1.store
  file = UserFile[index]
  file.name = "file#{index}"
  file.store
  user = User[index*2]
  user.age = index
  user.city = "Small town#{index}"
  user.file = file
  user.accounts << account1
  user.store

  account2 = Account[index * 2 + 1]
  account2.password = "pass#{index * 2 + 1}"
  account2.store
  user = User[index*2 + 1]
  user.age = index * 2
  user.file = file
  user.accounts << account1
  user.accounts << account2
  user.store
end

# Force the creation of index key with empty proxy.
House.find_by_name("doesn't exist")

Database.instance.close_database
