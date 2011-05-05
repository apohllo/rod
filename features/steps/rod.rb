$:.unshift "lib"
require File.dirname(__FILE__) + '/fred'
require 'test/unit/assertions'

World(Test::Unit::Assertions)

Before do
  @freds = {}
end

Given /^the library works in development mode$/ do
  Rod::Service.development_mode = true
end

Given /^(the )?database is created$/ do |ignore|
  Rod::Model.close_database if Rod::Model.opened?
  File.delete("tmp/test.dat") if File.exist?("tmp") && File.exist?("tmp/test.dat")
  Rod::Model.create_database('tmp/test.dat')
end

Given /^the class space is cleared$/ do
  RodTest.constants.each{|c| RodTest.send(:remove_const,c.to_sym)}
  Rod::Model.close_database(true) if Rod::Model.opened?
end


When /^I reopen database for reading$/ do
  Rod::Model.close_database
  Rod::Model.clear_cache
  Rod::Model.open_database('tmp/test.dat')
end

Then /^database should be opened for reading$/ do
  assert Rod::Model.opened?
  assert Rod::Model.readonly_data?
end

Given /^Fred is (\d+) years old/ do |age_str|
  @fred = RodScenario::Fred.new
  @fred.age = Integer(age_str)
end

When /^I store Fred$/ do
  @fred.store
  @id = @fred.rod_id
end


When /^I restore Fred$/ do
  @fred = RodScenario::Fred.find_by_rod_id(@id)
end


Then /^Fred should be (\d+) years old/ do |expected_age|
  assert_equal Integer(expected_age), @fred.age
end

Given /^(\w+) Fred is (\w+)$/ do |name, sex|
  @freds[name] = sex
end

When /^I store all Freds$/ do
  @freds.each do |name, sex|
    fred = RodScenario::Fred.new
    fred.age = 18
    fred.sex = sex
    fred.store
  end
end

Then /^database should contain (\d+) (\w+) Freds$/ do |expected_count, sex|
  assert_equal Integer(expected_count), RodScenario::Fred.find_all_by_sex(sex).count
end
