require 'rspec/expectations'
require File.join(File.dirname(__FILE__),"test_helper")

def get_class(class_name)
  klass = RodTest.const_get(class_name) rescue nil
  if klass.nil?
    superclass = RodTest::TestModel
    klass = Class.new(superclass)
    RodTest.const_set(class_name,klass)
  end
  klass
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
  when "fourth"
    3
  when "fifth"
    4
  when "sixth"
    5
  when "seventh"
    6
  when "last"
    -1
  when Fixnum
    position
  end
end

################################################################
# Given
################################################################
Given /^the following class(?:es)? (?:is|are) defined:$/ do |text|
  eval(text,RodTest.bd)
end

################################################################
# When
################################################################
# When I create a Caveman
When /^I create a(?:nother|n)? (\w+)$/ do |class_name|
  @instance = get_class(class_name).new
  @instances[class_name] ||= []
  @instances[class_name] << @instance
end

# When I create a Caveman with 'Fred' name and 'Flintstone' surname
When /^I create a(?:nother|n)? (\w+) with (.*)$/ do |class_name,rest|
  hash = {}
  rest.split(/\s+and\s+/).each do |pair|
    matched = pair.match(/'(?<value>[^']*)' (?<name>\w+)/)
    hash[matched[:name].to_sym] =  get_value(matched[:value])
  end
  begin
    @instance = get_class(class_name).new(hash)
    @instances[class_name] ||= []
    @instances[class_name] << @instance
  rescue Exception => ex
    @error = ex
  end
end

# When I fetch the first Caveman (created)
When /^I fetch the (\w+) (\w+)( created)?$/ do |position,class_name,created|
  created = !created.nil?
  @instance = get_instance(class_name,position,created)
end

# When his name is 'Fred' (multiplied 300 times)
When /^(?:his|her|its) (\w+) is '([^']*)'(?: multiplied (\d+) times)?(?: now)?$/ do |field,value,multiplier|
  value = get_value(value)
  if multiplier
    value *= multiplier.to_i
  end
  @instance.__send__("#{field}=".to_sym,value)
end

# When his name is nil
When /^(?:his|her|its) (\w+) is nil$/ do |field|
  @instance.send("#{field}=".to_sym,nil)
end

# When his car is the first car created
When /^(?:his|her|its) (\w+) is the (\w+) (\w+) created$/ do |field,position,class_name|
  @instance.send("#{field}=".to_sym,get_instance(class_name,position,true))
end

# When his cars contain the first car created
When /^(?:his|her|its) (\w+) contain the (\w+) (\w+) created$/ do |field,position,class_name|
  @instance.send("#{field}".to_sym) << get_instance(class_name,position,true)
end

# When his cars contain nil
When /^(?:his|her|its) (\w+) contain nil$/ do |field|
  @instance.send("#{field}".to_sym) << nil
end

# When I access the Cavemen name index
When /^I access the (\w+) (\w+) index$/ do |class_name,field|
  get_class(class_name).send("find_by_#{field}",nil)
end

# When I remember the first Caveman
When /^I remember the (\w+) (\w+)$/ do |position,class_name|
  @remembered = get_instance(class_name,position)
end

# When I remove the first of his books
When /^I remove the (\w+) of (?:his|her|its) (\w+)$/ do |position,property|
  @instance.send(property).delete_at(get_position(position))
end

# When I iterate over the name index of User
When /^I iterate over the (\w+) index of (\w+)$/ do |field,class_name|
  klass = get_class(class_name)
  index = klass.property(field.to_sym).index
  @results = []
  index.each do |key,values|
    values.each do |value|
      @results << [key,value]
    end
  end
end
