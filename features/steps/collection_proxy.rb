require 'mocha'

def create_item(index)
  rod_id = index + 1
  element = Rod::Model::Base.new
  element.expects(:rod_id).returns(rod_id).at_least(0)
  Rod::Model::Base.expects(:find_by_rod_id).with(rod_id).returns(element).at_least(0)
  element
end

def create_collection(size,offset=0)
  offset.upto(size-1).map do |index|
    create_item(index)
  end
end

# Given the initial size of the collection proxy is 10
Given /^the initial size of the collection proxy is (\d+)$/ do |size|
  @offset = 0
  size = size.to_i
  @array = create_collection(size,@offset)
  db = Object.new
  @array.each.with_index do |element,index|
    db.expects(:join_index).with(0,index).returns(element).at_least(0)
  end
  @proxy = Rod::CollectionProxy.new(@array.size,db,@offset,Rod::Model::Base)
  @offset += size
end

#When I append a new item 10 times
When /^I append a new item(?: (\d+) times)?$/ do |count|
  count = count && count.to_i || 1
  count.times do |index|
    item = create_item(@offset)
    @proxy << item
    @array << item
    @offset += 1
  end
end

#When I insert a new item at position 1
When /^I insert a new item at position (\d+)(?: (\d+) times)?$/ do |position,count|
  (count && count.to_i || 1).times do
    item = create_item(@offset)
    @proxy.insert(position.to_i,item)
    @array.insert(position.to_i,item)
    @offset += 1
  end
end

#When I insert an item with rod_id = 1 at position 1
When /^I insert an item with rod_id = (\d+) at position (\d+)(?: (\d+) times)?$/ do |rod_id,position,count|
  (count && count.to_i || 1).times do
    item = Rod::Model::Base.find_by_rod_id(rod_id.to_i)
    @proxy.insert(position.to_i,item)
    @array.insert(position.to_i,item)
  end
end

#When I delete an item at position 1
When /^I delete an item at position (\d+)(?: (\d+) times)?$/ do |position,count|
  (count && count.to_i || 1).times do
    @proxy.delete_at(position.to_i)
    @array.delete_at(position.to_i)
  end
end

#When I delete an item with rod_id = 1
When /^I delete an item with rod_id = (\d+)$/ do |rod_id|
  item = Rod::Model::Base.find_by_rod_id(rod_id.to_i)
  @proxy.delete(item)
  @array.delete(item)
end

#Then the size of the collection proxy should be 20
Then /^the size of the collection proxy should be (\d+)$/ do |size|
  @proxy.size.should == size.to_i
end

#Then the collection proxy should be valid
Then /^the collection proxy should behave like an array$/ do
  @proxy.to_a.should == @array
end

#Then the collection proxy should be empty
Then /^the collection proxy should be empty$/ do
  @proxy.to_a.should be_empty
end

#Then an exception should be raised when the collection is modified during iteration
Then /^an exception should be raised when the collection is modified during iteration$/ do
  (lambda do
    @proxy.each do |item|
      @proxy << create_item(@offset)
    end
  end).should raise_exception
  (lambda do
    @proxy.each do |item|
      @proxy.detete_at(0)
    end
  end).should raise_exception
end
