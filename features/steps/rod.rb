require File.join(File.dirname(__FILE__),"test_helper")

Given /^the library works in development mode$/ do
  Rod::Service.development_mode = true
end

Given /^(the )?database is created$/ do |ignore|
  RodTest::Database.instance.close_database if RodTest::Database.instance.opened?
  File.delete("tmp/test.dat") if File.exist?("tmp") && File.exist?("tmp/test.dat")
  RodTest::Database.instance.create_database('tmp/test.dat')
  @instances = {}
end

Given /^the class space is cleared$/ do
  if Dir.glob("/home/fox/.ruby_inline/Inline_Rod*").size > 0
    `rm /home/fox/.ruby_inline/Inline_Rod*`
  end
  RodTestSpace.constants.each{|c| RodTestSpace.send(:remove_const,c.to_sym)}
  RodTest::Database.instance.close_database(true) if RodTest::Database.instance.opened?
end


When /^I reopen database for reading$/ do
  RodTest::Database.instance.close_database
  RodTest::Database.instance.clear_cache
  RodTest::Database.instance.open_database('tmp/test.dat')
end

Then /^database should be opened for reading$/ do
  RodTest::Database.instance.opened?.should be_true
  RodTest::Database.instance.readonly_data?.should be_true
end
