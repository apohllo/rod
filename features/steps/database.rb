require File.join(File.dirname(__FILE__),"test_helper")

def get_db(db_name)
  @databases ||= {}
  case db_name
  when "database"
    @databases[:default]
  else
    @databases[db_name]
  end
end

def initialize_db(db_name)
  raise "Database already created" if @databases[:db_name]
  @databases ||= {}
  @databases[db_name] = Rod::Database::Base.new
end


#$ROD_DEBUG = true

# Given the first_database is created in tmp/tests
Given /^(?:the )?(\w+) is created(?: in (\S+))?$/ do |db_name,location|
  get_db(db_name).close if get_db(db_name).opened?
  if location
    db_location = location
  else
    db_location = "tmp/#{db_name}"
  end
  get_db(db_name).create(db_location)
  @instances = {}
end

Given /^the default database is initialized$/ do
  initialize_db(:default) unless get_db("database")
end

# Should be split
# I reopen the database for reading in tmp/location1
When /^I reopen (?:the )?(\w+)( for reading)?(?: in (\S+))?$/ do |db_name,reading,location|
  if location
    db_location = location
  else
    db_location = "tmp/#{db_name}"
  end
  get_db(db_name).close
  readonly = reading.nil? ? false : true
  get_db(db_name).open(db_location,readonly: readonly)
end

# I open the database for reading in tmp/location1
When /^I open (?:the )?(\w+)( for reading)?(?: in (\S+))?$/ do |db_name,reading,location|
  if location
    db_location = location
  else
    db_location = "tmp/#{db_name}"
  end
  get_db(db_name).instance.clear_cache
  readonly = reading.nil? ? false : true
  get_db(db_name).instance.open_database(db_location,readonly)
end

Then /^database should be opened for reading$/ do
  RodTest::Database.instance.opened?.should be_true
  RodTest::Database.instance.readonly_data?.should be_true
end
