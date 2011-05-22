require 'rspec/expectations'
require File.join(File.dirname(__FILE__),"test_helper")

def get_class(class_name,type=:model)
  klass = RodTest.const_get(class_name) rescue nil
  if klass.nil?
    superclass =
      case type
      when :model
        RodTest::TestModel
      when :db
        Rod::Database
      end
    klass = Class.new(superclass)
    RodTest.const_set(class_name,klass)
  end
  klass
end

def get_db(db_name)
  case db_name
  when "database"
    RodTest::Database
  else
    get_class(db_name,:db)
  end
end

def get_instance(class_name,position,cache=false)
  if cache
    @instances[class_name][get_position(position)]
  else
    get_class(class_name)[get_position(position)]
  end
end

def get_value(value)
  case value
  when /^(-)?\d+\.\d+$/
    value.to_f
  when /^(-)?\d+$/
    value.to_i
  when /^:/
    value[1..-1].to_sym
  else
    value = value.scan(/[^\d\\]+|\\\d+/).map do |segment|
      case segment
      when /\\\d+/
        $&.to_i.chr
      else
        segment
      end
    end.join("")
    value
  end
end

def get_position(position)
  case position
  when "first"
    0
  when "second"
    1
  when "third"
    2
  when "last"
    -1
  when Fixnum
    position
  end
end

################################################################
# Given
################################################################
Given /^the model is connected with the default database$/ do
  RodTest::TestModel.send(:database_class,RodTest::Database)
end

Given /^a class (\w+) inherits from ([\w:]+)$/ do |name1,name2|
  if name2 =~ /::/
    base_module = Module
  else
    base_module = RodTest
  end
  class2 = name2.split("::").inject(base_module){|m,n| m.const_get(n)}
  class1 = Class.new(class2)
  RodTest.const_set(name1,class1)
end

Given /^a class (\w+) has an? (\w+) field of type (\w+)( with (\w+) index)?$/ do |class_name,field,type,index,index_type|
  index_type = index_type == "flat" ? :flat : :segmented
  if index
    get_class(class_name).send(:field,field.to_sym,type.to_sym,:index => index_type)
  else
    get_class(class_name).send(:field,field.to_sym,type.to_sym)
  end
end

Given /^a class (\w+) has one (\w+ )?(\w+)$/ do |class_name,type,assoc|
  options = {}
  unless type.nil?
    case type
    when /polymorphic/
      options[:polymorphic] = true
    end
  end
  get_class(class_name).send(:has_one,assoc.to_sym,options)
end

Given /^a class (\w+) has many (\w+ )?(\w+)$/ do |class_name,type,assoc|
  options = {}
  unless type.nil?
    case type
    when /polymorphic/
      options[:polymorphic] = true
    end
  end
  get_class(class_name).send(:has_many,assoc.to_sym,options)
end

################################################################
# When
################################################################
When /^I create a(nother|n)? (\w+)$/ do |ignore,class_name|
  @instance = get_class(class_name).new
  @instances[class_name] ||= []
  @instances[class_name] << @instance
end

When /^I create and store the following (\w+)\(s\):$/ do |class_name,table|
  klass = get_class(class_name)
  table.hashes.each do |attributes|
    instance = klass.new
    attributes.each do |field,value|
      instance.send("#{field}=",get_value(value))
    end
    @instances[class_name] ||= []
    @instances[class_name] << instance
    instance.store
  end
end

When /^(his|her|its) (\w+) is '([^']*)'( multiplied (\d+) times)?$/ do |ignore,field,value,multi,multiplier|
  value = get_value(value)
#  p value
  if multi
    value *= multiplier.to_i
  end
  @instance.send("#{field}=".to_sym,value)
end

When /^(his|her|its) (\w+) is nil$/ do |ignore,field|
  @instance.send("#{field}=".to_sym,nil)
end


When /^(his|her|its) (\w+) is the (\w+) (\w+) created$/ do |ignore,field,position,class_name|
  @instance.send("#{field}=".to_sym,get_instance(class_name,position,true))
end

When /^(his|her|its) (\w+) contain the (\w+) (\w+) created$/ do |ignore,field,position,class_name|
  @instance.send("#{field}".to_sym) << get_instance(class_name,position,true)
end

When /^(his|her|its) (\w+) contain nil$/ do |ignore,field|
  @instance.send("#{field}".to_sym) << nil
end

When /^I store (him|her|it) in the database( (\d+) times)?$/ do |ignore,times,count|
  if times
    count.to_i.times do |index|
      instance = @instance.dup
      instance.store
    end
  else
    @instance.store
  end
end

When /^I store the (\w+) (\w+) in the database$/ do |position,class_name|
  get_instance(class_name,position,true).store
end

When /^I access the (\w+) (\w+) index$/ do |class_name,field|
  get_class(class_name).send("find_by_#{field}",nil)
end

################################################################
# Then
################################################################
Then /^there should be (\d+) (\w+)(\([^)]*\))?$/ do |count,class_name,ignore|
  get_class(class_name).count.should == count.to_i
end

Then /^the (\w+) of the (\w+) (\w+) should be '([^']*)'$/ do |field, position, class_name,value|
  get_instance(class_name,position).send(field.to_sym).should == get_value(value)
end

Then /^the (\w+) of the (\w+) (\w+) should be '([^']*)'( multiplied (\d+) times)$/ do |field, position, class_name,value,multi,multiplier|
  value = get_value(value)
  if multi
    value *= multiplier.to_i
  end
  get_instance(class_name,position).send(field.to_sym).should == value
end

Then /^the (\w+) (\w+) should not have a (\w+) field$/ do |position, class_name, field|
  (lambda {get_instance(class_name,position).send(field.to_sym)}).should raise_error(NoMethodError)
end

Then /^the (\w+) (\w+) should not have (a|an )?(\w+)$/ do |position, class_name, ignore, assoc|
  (lambda {get_instance(class_name,position).send(assoc.to_sym)}).should raise_error(NoMethodError)
end

Then /^the (\w+) (\w+) should not exist$/ do |position,class_name|
  (lambda {get_instance(class_name,position)}).should raise_error(IndexError)
end

Then /^the (\w+) of the (\w+) (\w+) should be equal to the (\w+) (\w+)$/ do |field, position1,class1,position2,class2|
  get_instance(class1,position1).send(field.to_sym).should ==
    get_instance(class2,position2,true)
end

Then /^the (\w+) of the (\w+) (\w+) should be nil$/ do |field,position1,class1|
  get_instance(class1,position1).send(field.to_sym).should == nil
end


Then /^the (\w+) (\w+) should have (\d+) (\w+)$/ do |position,class_name,count,field|
  get_instance(class_name,position).send(field.to_sym).count.should == count.to_i
end

Then /^(\w+)(\([^)]*\))? from (\d+) to (\d+) should have '([^']*)' (\w+)$/ do |class_name,ignore,first,last,value,field|
  (first.to_i - 1).upto(last.to_i - 1) do |index|
    get_instance(class_name,index).send(field.to_sym).should == value
  end
end

Then /^(\w+)(\([^)]*\))? from (\d+) to (\d+) should have a(n)? (\w+) equal to the (\w+) (\w+)$/ do |class1,ignore,first,last,ignore1,field,position,class2|
  (first.to_i - 1).upto(last.to_i - 1) do |index|
    get_instance(class1,index).send(field.to_sym).should == get_instance(class2,position)
  end
end

Then /^(\w+)(\([^)]*\))? from (\d+) to (\d+) should have (\d+) (\w+)$/ do |class1,ignore,first,last,count,field|
  (first.to_i - 1).upto(last.to_i - 1) do |index|
    get_instance(class1,index).send(field.to_sym).count.should == count.to_i
  end
end

Then /^(\w+)(\([^)]*\))? from (\d+) to (\d+) should have (\w+) of (\w+) equal to the (\w+) (\w+) created$/ do |class1,ignore,first,last,position1,field,position2,class2|
  (first.to_i - 1).upto(last.to_i - 1) do |index|
    get_instance(class1,index).send(field.to_sym)[get_position(position1)] == get_instance(class2,position2)
  end
end

Then /^the (\w+) of (\w+) of the (\w+) (\w+) should be equal to the (\w+) (\w+)$/ do |position0,field,position1,class1,position2,class2|
  get_instance(class1,position1).send(field.to_sym)[get_position(position0)].should ==
    get_instance(class2,position2,true)
end

Then /^the (\w+) of (\w+) of the (\w+) (\w+) should be nil$/ do |position0,field,position1,class1|
  get_instance(class1,position1).send(field.to_sym)[get_position(position0)].should == nil
end

Then /^(his|her|its) (\w+) should be '([^']*)'$/ do |ignore,field, value|
  value = get_value(value)
  @instance.send(field.to_sym).should == value
end

Then /^the (\w+) (\w+) should be equal with the instance$/ do |position1,class1|
  instance1 = get_instance(class1,position1)
  instance1.should == @instance
end

Then /^the (\w+) (\w+) should be identical with the (\w+) (\w+)$/ do |position1,class1,position2,class2|
  instance1 = get_instance(class1,position1)
  instance2 = get_instance(class2,position2)
  instance1.object_id.should == instance2.object_id
end

Then /^there should be (\d+) (\w+)(\([^)]*\))? with '([^']*)' (\w+)$/ do |count,class_name,ignore,value,field|
  get_class(class_name).send("find_all_by_#{field}",get_value(value)).count.should == count.to_i
end

Then /^I should be able to iterate( with index)? over these (\w+)\(s\)$/ do |with_index,class_name|
  if with_index
    (lambda {get_class(class_name).each.with_index{|e,i| e}}).should_not raise_error(Exception)
  else
    (lambda {get_class(class_name).each{|e| e}}).should_not raise_error(Exception)
  end
end

Then /^I should be able to find a (\w+) with '([^']*)' (\w+) and '([^']*)' (\w+)$/ do |class_name,value1,field1,value2,field2|
  get_class(class_name).find{|e| e.send(field1) == get_value(value1) && e.send(field2) == get_value(value2)}.should_not == nil
end

Then /^there should be (\d+) (\w+)(\([^)]*\))? with (\w+) (below|above) (\d+)( with index (below|above) (\d+))?$/ do |count1,class_name,ignore,field,relation1,value,with_index,relation2,count2|
  relation1 = relation1 == "below" ? :< : :>
  relation2 = relation2 == "below" ? :< : :>
  if with_index
    get_class(class_name).each.with_index.select{|e,i| e.send(field).send(relation1,value.to_i) &&
      i.send(relation2,count2.to_i)}.size.should == count1.to_i
  else
    get_class(class_name).select{|e| e.send(field).send(relation1, value.to_i)}.size.should == count1.to_i
  end

end
