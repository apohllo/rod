################################################################
# Then
################################################################
# Then there should be 5 User(s)
Then /^there should be (\d+) (\w+)(?:\([^)]*\))?$/ do |count,class_name|
  get_class(class_name).count.should == count.to_i
end

# Then the name of the first User should be 'John'
Then /^the (\w+) of the (\w+) ([A-Z]\w+) should be '([^']*)'$/ do |field, position, class_name,value|
  get_instance(class_name,position).send(field.to_sym).should == get_value(value)
end

Then /^the (\w+) of the (\w+) (\w+) should be '([^']*)'( multiplied (\d+) times)$/ do |field, position, class_name,value,multi,multiplier|
  value = get_value(value)
  if multi
    value *= multiplier.to_i
  end
  get_instance(class_name,position).send(field.to_sym).should == value
end

Then /^the (\w+) of the remembered instance should be '([^']*)'( multiplied (\d+) times)?$/ do |field, value,multi,multiplier|
  value = get_value(value)
  if multi
    value *= multiplier.to_i
  end
  @remembered.send(field.to_sym).should == value
end

Then /^the (\w+) (\w+) should not have a (\w+) field$/ do |position, class_name, field|
  (lambda {get_instance(class_name,position).send(field.to_sym)}).should raise_error(NoMethodError)
end

Then /^the (\w+) (\w+) should not have (a|an )?(\w+)$/ do |position, class_name, ignore, assoc|
  (lambda {get_instance(class_name,position).send(assoc.to_sym)}).should raise_error(NoMethodError)
end

Then /^the (\w+) (\w+) should not exist$/ do |position,class_name|
  get_instance(class_name,position).should == nil
end

Then /^the (\w+) of the (\w+) (\w+) should be equal to the (\w+) (\w+)( persisted)?$/ do |field, position1,class1,position2,class2,persisted|
  created = !persisted
  get_instance(class1,position1).send(field.to_sym).should ==
    get_instance(class2,position2,created)
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

Then /^the (\w+) of (\w+) of the (\w+) (\w+) should be equal to the (\w+) (\w+)( persisted)?$/ do |position0,field,position1,class1,position2,class2,persisted|
  created = !persisted
  get_instance(class1,position1).send(field.to_sym)[get_position(position0)].should ==
    get_instance(class2,position2,created)
end

Then /^the (\w+) of (\w+) of the (\w+) (\w+) should be nil$/ do |position0,field,position1,class1|
  get_instance(class1,position1).send(field.to_sym)[get_position(position0)].should == nil
end

# Then his name should be 'Fred'
Then /^(?:his|her|its) (\w+) should be '([^']*)'$/ do |property, value|
  value = get_value(value)
  @instance.send(property.to_sym).should == value
end

# Then his name should be nil
Then /^(?:his|her|its) (\w+) should be nil$/ do |property|
  @instance.send(property.to_sym).should == nil
end

# Then his items should be empty
Then /^(?:his|her|its) (\w+) should be empty$/ do |property|
  @instance.send(property.to_sym).should be_empty
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

Then /^there should be (\d+) (\w+)(?:\([^)]*\))? with '([^']*)' (\w+)$/ do |count,class_name,value,field|
  get_class(class_name).send("find_all_by_#{field}",get_value(value)).count.should == count.to_i
end

# Then there should exist a User with 'Adam' name
Then /^there should exist a(?:n)? (\w+) with '([^']*)' (\w+)$/ do |class_name,value,field|
  get_class(class_name).send("find_by_#{field}",get_value(value)).should_not == nil
end

# Then there should be 5 User(s) with the first Dog as dog
Then /^there should be (\d+) (\w+)(?:\([^)]*\))? with the (\w+) (\w+) (?:as|(?:in their)) (\w+)$/ do |count,class1,position,class2,assoc|
  get_class(class1).send("find_all_by_#{assoc}",get_instance(class2,position)).count.should == count.to_i
end

# Then there should exist a User with the first Dog as dog
Then /^there should exist a(?:n)? (\w+) with the (\w+) (\w+) as (\w+)$/ do |class1,position,class2,assoc|
  get_class(class1).send("find_by_#{assoc}",get_instance(class2,position)).should_not == nil
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

Then /^([\w:]+) should be raised$/ do |exception|
  @error.class.to_s.should == exception
end

# Then some User with 'Fred' name should be equal to the first User
Then /^some (\w+) with '([^']*)' (\w+) should be equal to the (\w+) (\w+)$/ do |class1,value,field,position2,class2|
  objects = get_class(class1).send("find_all_by_#{field}",get_value(value))
  expected = get_instance(class2,position2)
  objects.any?{|o| o == expected }.should == true
end

# Then the first User with 'Fred' name should be equal to the first User
Then /^the first (\w+) with '([^']*)' (\w+) should be equal to the (\w+) (\w+)$/ do |class1,value,field,position2,class2|
  get_class(class1).send("find_by_#{field}",get_value(value)).should ==
    get_instance(class2,position2)
end

# Then there should be 1 User with 'John' name in the iteration results
Then /^there should be (\d) (\w+)(?:\([^)]*\))? with '([^']*)' (\w+) in the iteration results$/ do |count,class_name,value,field|
  @results.select{|k,v| k == value && v.send(field.to_sym) == value}.size.should == count.to_i
end

#Then the intersection size of automobiles of the first and the second Caveman should equal 2
Then /^the intersection size of (\w+) of the (\w+) and the (\w+) (\w+) should equal (\d+)$/ do |field,position1,position2,klass,count|
  elements1 = get_instance(klass,position1).send(field.to_sym)
  elements2 = get_instance(klass,position2).send(field.to_sym)
  elements1.intersection_size(elements2).should == count.to_i
end
