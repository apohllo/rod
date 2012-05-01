require File.join(File.dirname(__FILE__),"test_helper")

#$ROD_DEBUG = true

Given /^the library works in development mode$/ do
  Rod::Database.development_mode = true
end

Given /^(?:the )?(\w+) is created(?: in (\S+))?$/ do |db_name,location|
  get_db(db_name).instance.close_database if get_db(db_name).instance.opened?
  if location
    db_location = location
  else
    db_location = "tmp/#{db_name}"
  end
  get_db(db_name).instance.create_database(db_location)
  @instances = {}
end

Given /^a class (\w+) is connected to (\w+)$/ do |class_name,db_name|
  get_class(class_name).send(:database_class,get_class(db_name,:db))
end

Given /^the class space is cleared$/ do
  #RodTest::Database.instance.close_database(true) if RodTest::Database.instance.opened?
  RodTest.constants.each do |constant|
    klass = RodTest.const_get(constant)
    if constant.to_s =~ /Database/
      if klass.instance.opened?
        klass.instance.close_database(true)
      end
    end
    RodTest.send(:remove_const,constant)
  end
  # TODO separate step?
  default_db = Class.new(Rod::Database)
  RodTest.const_set("Database",default_db)
  default_model = Class.new(Rod::Model)
  RodTest.const_set("TestModel",default_model)
end

# Should be split
# I reopen the database for reading in tmp/location1
When /^I reopen (?:the )?(\w+)( for reading)?(?: in (\S+))?$/ do |db_name,reading,location|
  if location
    db_location = location
  else
    db_location = "tmp/#{db_name}"
  end
  get_db(db_name).instance.close_database
  get_db(db_name).instance.clear_cache
  readonly = reading.nil? ? false : true
  get_db(db_name).instance.open_database(db_location,readonly)
end

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
