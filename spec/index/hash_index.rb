require 'bundler/setup'
require 'minitest/autorun'
require 'rod/utils'
require 'inline'
require 'rod/model/resource' # Need to change implementation of [] method i lib/rod/index/base.rb
require 'rspec/expectations'
require_relative '../../lib/rod/index/hash_index'
require_relative '../../lib/rod/exception'
require_relative '../spec_helper'

module Rod
  module Index
    describe HashIndex < Base do
      subject                     { HashIndex.new(path, klass, options={:index=>:hash,:proxy_factory=>proxy_factory}) }
      let(:path)                  { 'tmp/hash_index' }
      let(:klass)                 { Object.new() }      
      let(:proxy_factory)					{ stub(proxy_factory = Object.new).new { collection_proxy } 
                                    proxy_factory
                                  }
      let(:collection_proxy)    	{ Object.new }
      
      def check_values(subject, values)
        subject.each_for('abc') do |value|
          value.must_equal values.shift
        end
        values.must_be_empty 
      end
      
      describe "without creating index" do
      
        after(:each) do
          subject.destroy 
        end

        it "must be closed on init" do
          subject.wont_be :opened?
        end       
        
        it "allows to create itself" do
          (->() { subject.open(:create => true) }).must_be_silent
          subject.must_be :opened?
          subject.destroy
        end
          
        it "mustn't allow to create itself twice" do
          subject.open(:create => true)
          (->() { subject.open(:create => true) }).must_raise RodException
          subject.destroy
        end

      end

      describe "with created index" do
      
        before do
          subject.open(:create => true)
          subject.close
        end

        after do
          subject.close
          subject.destroy 
        end
      
        after(:each) do
          subject.close
        end

        it "allows to open itself" do
          subject.wont_be :opened?
          subject.open()
          subject.must_be :opened?
        end
      
        it "mustn't allow to open itself twice" do
          subject.open()
          (->() { subject.open(:create => true) }).must_raise RodException
        end
      
        it "allows to close itself twice" do
          subject.open()
          subject.close
          subject.close
          (->() { subject.close }).must_be_silent
          subject.wont_be :opened?
        end
      
        it "must be in closed state after being closed" do
          subject.open()
          subject.must_be :opened?
          subject.close
          subject.wont_be :opened?
        end

        it "allows to destroy itself" do
          subject.destroy
          (->() { subject.open() }).must_raise DatabaseError
        end
              
        it "allows to recreate the index after it has been destroyed" do
          subject.destroy
          (->() { subject.open() }).must_raise DatabaseError
          (->() { subject.open(:create => true) }).must_be_silent
        end

        describe "with stubbed collection proxy" do
          before do
            stub(collection_proxy).database { subject }
            stub(collection_proxy).key { 'abc' }
          end
           
          it "returns exactly the same values as in the collection proxy" do
            returned_collection = subject['abc']
            returned_collection.must_equal collection_proxy 
          end
          
          it "copies index to the given index" do
            skip("To pass this test implement #TODO 206")
            index_new = HashIndex.new('tmp/some_path', 'some class', options={:index=>:hash, :proxy_factory=>proxy_factory})
          
            index_new.copy(subject) 
            index_new.path.must_equal subject.path
            index_new.klass.must_equal subject.klass
          end
          
          it "must raise KeyMissing Error if index doesn't contain given key" do
            subject.open(:truncate => true)
            (->() { subject.get_first('abc') }).must_raise KeyMissing 
          end
          
          it "must put key-value pair into the index" do
            subject.open(:truncate => true)         
            subject.put('abc', 1)
            
            first_key = subject.get_first('abc')
            first_key.must_equal 1
          end
          
          it "saves and returns different value for different keys" do
            subject.open(:truncate => true)
            subject.put('abc', 1)
            subject.put('bcd', 11)
            subject.save
            subject.open()
          
            subject.get_first('abc').must_equal 1
            subject.get_first('bcd').must_equal 11
          end

          describe "with some content" do
            
            before (:each) do
              subject.open(:truncate => true)         
      
              subject.put('abc', 1)
              subject.put('abc', 2)
              subject.put('abc', 3)
              subject.put('bcd', 4)            
            end

            it "must remove all key-value pairs from index when truncated" do
              subject.close
              subject.open(:truncate => true)
              (->() { subject.get_first('abc') }).must_raise KeyMissing 
              (->() { subject.get_first('bcd') }).must_raise KeyMissing 
            end

            it "returns proper values for given keys" do
              subject.get_first('abc').must_equal 1
              subject.get_first('bcd').must_equal 4
            end
         
            it "returns all values for the a key with many values" do
              values = [1,2,3]
              check_values(subject, values)
            end
          
            it "deletes first value for the given key" do
              subject.get_first('abc').must_equal 1
              subject.delete('abc', 1)
              subject.get_first('abc').must_equal 2
            end
              
            it "deletes the second value for the given key" do 
              values = [1,2,3]
              check_values(subject, values)

              subject.delete('abc', 2)
                
              values = [1,3]
              check_values(subject, values)
            end
          
            it "deletes all values for the given key" do
              values = [1,2,3]
              check_values(subject, values)

              subject.delete('abc')
              (->() { subject.get_first('abc') }).must_raise KeyMissing 
            end
          end
        end
      end
    end
  end
end
