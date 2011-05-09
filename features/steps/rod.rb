require File.join(File.dirname(__FILE__),"test_helper")

Given /^the library works in development mode$/ do
  Rod::Service.development_mode = true
end

Given /^(the )?(\w+) is created$/ do |ignore,db_name|
  get_db(db_name).instance.close_database if get_db(db_name).instance.opened?
  if File.exist?("tmp")
    if File.exist?("tmp/#{db_name}.dat")
      File.delete("tmp/#{db_name}.dat")
    end
  end
  get_db(db_name).instance.create_database("tmp/#{db_name}.dat")
  @instances = {}
end

Given /^a class (\w+) is connected to (\w+)$/ do |class_name,db_name|
  get_class(class_name).send(:database_class,get_class(db_name,:db))
end

Given /^the class space is cleared$/ do
  if Dir.glob("/home/fox/.ruby_inline/Inline_Rod*").size > 0
    `rm /home/fox/.ruby_inline/Inline_Rod*`
  end
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


When /^I reopen (\w+) for reading$/ do |db_name|
  get_db(db_name).instance.close_database
  get_db(db_name).instance.clear_cache
  get_db(db_name).instance.open_database("tmp/#{db_name}.dat")
end

Then /^database should be opened for reading$/ do
  RodTest::Database.instance.opened?.should be_true
  RodTest::Database.instance.readonly_data?.should be_true
end
