$:.unshift "lib"
require 'rod'

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
  Rod::Model.opened?.should be_true
  Rod::Model.readonly_data?.should be_true
end
