require 'bundler/setup'
require 'minitest/autorun'
require 'rod/utils'
require 'inline'
require 'rod/model/resource' # This shouldn't be here, but i don't know how to fix it. If it is removed - test_0001 (Tests with stubbed collection proxy) fails.
require 'rspec/expectations'
require_relative '../../lib/rod/index/hash_index'
require_relative '../../lib/rod/exception'
require_relative '../spec_helper'

module Rod
  module Index
    describe HashIndex < Base do
      subject                     { HashIndex.new(path, klass, options={:index=>:hash,:proxy_factory=>proxy_factory}) }
      let(:path)                  { "tmp/hash_index" }
      let(:klass)                 { Object.new() }      
      let(:proxy_factory)					{ stub(proxy_factory = Object.new).new { collection_proxy } 
                                    proxy_factory
                                  }
      let(:collection_proxy)    	{ Object.new }

      before do
        subject.open('tmp/hash_index.db', :create => true)
        subject.close
      end

      # I did this, to be sure that the index will be closed after each test.
      after(:each) do
        subject.close
      end

      after do
        subject.close
        subject.destroy 
      end
        
      it "allows to destroy itself" do # not sure if written correctly
        subject.destroy
        (->() { subject.open('tmp/hash_index.db') }).must_raise DatabaseError
        (->() { subject.open('tmp/hash_index.db', :create => true) }).must_be_silent
      end
        
      it "allows to create itself" do
        subject.destroy
        (->() { subject.open('tmp/hash_index.db') }).must_raise DatabaseError
      end
      
      it "must be closed on init" do
        subject.wont_be :opened?
      end
        
      it "allows to open itself" do
        (->() { subject.open('tmp/hash_index.db') }).must_be_silent
      end
      
      it "mustn't allow to open itself twice" do
        subject.open('tmp/hash_index.db')
        (->() { subject.open('tmp/hash_index.db') }).must_raise RodException
      end
      
      it "allows to close itself twice" do
        subject.open('tmp/hash_index.db')
        subject.close
        (->() { subject.close }).must_be_silent
      end
       
      it "must be in opened state after being opend" do
        subject.open('tmp/hash_index.db')
        subject.must_be :opened?
      end
      
      it "must be in closed state after being closed" do
        subject.open('tmp/hash_index.db')
        subject.must_be :opened?
        subject.close
        subject.wont_be :opened?
      end

      describe "Tests with stubbed collection proxy" do
        
        before do
          stub(proxy_factory = Object.new).new {collection_proxy}
          stub(collection_proxy).database { subject }
          stub(collection_proxy).key { 'abc' }
        end
         
        it "returns exactly the same values as in the collection proxy" do
          returned_collection = subject['abc']
          returned_collection.must_equal collection_proxy 
        end
          
        it "copies index to the given index" do
          index_new = HashIndex.new('tmp/some_path', 'some class', options={:index=>:hash, :proxy_factory=>proxy_factory})
        
          index_new = index_new.copy(subject)
          # index_new.copy(subject) 
          # if written like this, doesn't work!
          # there's also something wrong, because this test sometimes passes, and sometimes doesn't :: TypeError: incompatible marshal file format (can't be read)
          # format version 4.8 required; 97.98 given
          # stil not workin'
          index_new.path.must_equal subject.path
          index_new.klass.must_equal subject.klass
        end
          
        it "Saves given key-value pairs in index" do
          subject.open('tmp/hash_index.db', :truncate => true)
          subject.put('abc', 1)
          subject.put('bcd', 11)
          subject.save # here could be close method as well
          subject.open('tmp/hash_index.db')
        
          first_key = subject.get_first('abc')
          first_key.must_equal 1
          second_key = subject.get_first('bcd')
          second_key.must_equal 11
        end
      
        it "must raise KeyMissing Error if index doesn't contain given key" do
          subject.open('tmp/hash_index.db', :truncate => true)
          (->() { subject.get_first('abc') }).must_raise KeyMissing 
        end
          
        it "must put key-value pair into the index" do
          subject.open('tmp/hash_index.db', :truncate => true)         
          subject.put('abc', 1)
          
          first_key = subject.get_first('abc')
          first_key.must_equal 1
        end

      end

      describe "Tests with stubbed collection proxy and predetermined data as kew-value pairs" do
          
        before (:each) do
          stub(proxy_factory = Object.new).new {collection_proxy}
          stub(collection_proxy).database { subject }
          stub(collection_proxy).key { 'abc' }
            
          subject.open('tmp/hash_index.db', :truncate => true)         

          subject.put('abc', 1)
          subject.put('abc', 2)
          subject.put('abc', 3)
          subject.put('bcd', 4)            
        end

        it "must remove all key-value pairs from index" do
          subject.close
          subject.open('tmp/hash_index.db', :truncate => true)
          (->() { subject.get_first('abc') }).must_raise KeyMissing 
          (->() { subject.get_first('bcd') }).must_raise KeyMissing 
        end

        it "must return proper value for given key" do
          first_key = subject.get_first('abc')
          first_key.must_equal 1
          second_key = subject.get_first('bcd')
          second_key.must_equal 4
        end
      
        it "must return proper values for the same key" do
          values = [1,2,3]
          subject.each_for('abc') do |value|
            value.must_equal values.shift
          end
          values.must_be_empty
        end
      
        it "deletes given value for the given key" do
          first_key = subject.get_first('abc')
          first_key.must_equal 1
          
          subject.delete('abc', 1)
        
          first_key = subject.get_first('abc')
          first_key.must_equal 2
        end
          
        it "deletes given value for the given key - 2" do #how to name it better? The only difference between this and the on above is that here we check all the values for given key.
          values = [1,2,3]
          subject.each_for('abc') do |value|
            value.must_equal values.shift
          end
          values.must_be_empty

          subject.delete('abc', 2)
            
          values = [1,3]
          subject.each_for('abc') do |value|
            value.must_equal values.shift
          end
          values.must_be_empty
        end
      
        it "deletes all values for the given key" do
          values = [1,2,3]
          subject.each_for('abc') do |value|
            value.must_equal values.shift
          end
          values.must_be_empty

          subject.delete('abc')
          (->() { subject.get_first('abc') }).must_raise KeyMissing 
        end
      
      end
    end
  end
end
