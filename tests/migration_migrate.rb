$:.unshift("lib")
require 'rod'
require File.join(".",File.dirname(__FILE__),"migration_model2")
require 'rspec/expectations'

$ROD_DEBUG = true
Rod::Database.development_mode = true

Database.instance.open_database("tmp/migration", :migrate => true,
                               :readonly => false)

user = User[0]
user.accounts << Account[0]
user.store

user = User[1]
user.accounts << Account[1]
user.store

Database.instance.close_database

test(?f,"tmp/migration/#{Rod::DATABASE_FILE}#{Rod::LEGACY_DATA_SUFFIX}").should == true
