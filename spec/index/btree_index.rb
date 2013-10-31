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

      describe "btree special features" do
        let(:key1)        { 'abc' }
        let(:key2)        { 'bcd' }
        let(:key3)        { 'efg' }
        let(:dumped_key1) { Marshal.dump(key1) }
        let(:dumped_key2) { Marshal.dump(key2) }
        let(:dumped_key3) { Marshal.dump(key3) }

        before (:each) do
          subject.open(:create => true)
        end

        after(:each) do
          subject.close
          subject.destroy
        end

        it "traverses the keys in alphabetic order" do
          subject.put(dumped_key1, 1)
          subject.put(dumped_key3, 5)
          subject.put(dumped_key2, 4)

          # dumped keys have the same order as string keys
          subject.each.zip([key1,key2,key3]).each do |(index_key,index_value),expected_key|
            index_key.must_equal expected_key
          end

        end
      end
    end
  end
end
