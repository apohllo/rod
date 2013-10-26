# When I store him in the database 10000 times
When /^I store (?:him|her|it) in the database(?: (\d+) times)?$/ do |count|
  if count
    count.to_i.times do |index|
      instance = @instance.dup
      instance.store
    end
  else
    @instance.store
  end
end

# When I store the first Caveman in the database
When /^I store the (\w+) (\w+) in the database$/ do |position,class_name|
  get_instance(class_name,position,true).store
end

# When I create and store the following Caveman(s):
#   | name | surname    |
#   | Fred | Flintstone |
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

