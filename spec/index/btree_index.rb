require 'bundler/setup'
require 'minitest/autorun'
require 'rod/utils'
require 'inline'
require 'rod/model/resource' # Need to change implementation of [] method i lib/rod/index/base.rb
require 'rspec/expectations'
require 'rod/index/btree_index'
require 'rod/exception'
require_relative '../spec_helper'
require_relative 'shared_berkeley_examples'

module Rod
  module Index
    describe BtreeIndex do
      include SharedExamplesSetup

      def dump(key)
        Marshal.dump(key)
      end

      subject           { BtreeIndex.new(path, klass, options) }
      let(:options)     { {index: :btree,proxy_factory: proxy_factory} }
      let(:index_class) { BtreeIndex }
      let(:path)        { 'tmp/btree_index' }

      describe "without creating index" do
        include ExamplesWithoutCreation
      end

      describe "with index creation" do
        include ExamplesWithCreation
      end

      describe "with stubbed collection proxy" do
        include ExamplesWithStubbedCollection
      end

      describe "with some content" do
        include ExamplesWithSomeContent
      end

      describe "without user-defined key order" do
        let(:key1)        { 'abc' }
        let(:key2)        { 'bcd' }
        let(:key3)        { 'efg' }

        before (:each) do
          subject.open(:create => true)
        end

        after(:each) do
          subject.close
          subject.destroy
        end

        it "traverses the keys in alphabetic order" do
          subject.put(dump(key1), 1)
          subject.put(dump(key3), 5)
          subject.put(dump(key2), 4)

          # dumped keys have the same order as string keys
          subject.each.zip([key1,key2,key3]).each do |(index_key,index_value),expected_key|
            index_key.must_equal expected_key
          end

        end
      end

      describe "with user-defined key order" do
        let(:options)     { {index: :btree,proxy_factory: proxy_factory, order: ->(a,b){ b.length <=> a.length} } }
        let(:key1)        { 'a' * 3 }
        let(:key2)        { 'a' * 4 }
        let(:key3)        { 'a' * 5 }
        let(:key4)        { 'a' * 7 }

        before (:each) do
          subject.open(:create => true)
        end

        after(:each) do
          subject.close
          subject.destroy
        end

        it "traverses the keys in reverse key-length order" do
          subject.put(dump(key1), 1)
          subject.put(dump(key2), 4)
          subject.put(dump(key3), 5)
          subject.put(dump(key4), 7)

          # dumped keys have the same order as string keys
          subject.each.zip([key4,key3,key2,key1]).each do |(index_key,index_value),expected_key|
            index_key.must_equal expected_key
          end
        end
      end
    end
  end
end
