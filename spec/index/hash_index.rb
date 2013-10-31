require 'bundler/setup'
require 'minitest/autorun'
require 'rod/utils'
require 'inline'
require 'rod/model/resource' # Need to change implementation of [] method i lib/rod/index/base.rb
require 'rspec/expectations'
require 'rod/index/hash_index'
require 'rod/exception'
require_relative '../spec_helper'
require_relative 'shared_berkeley_examples'

module Rod
  module Index
    describe HashIndex do
      include SharedExamplesSetup

      subject           { HashIndex.new(path, klass, options) }
      let(:options)     { {index: :hash,proxy_factory: proxy_factory} }
      let(:index_class) { HashIndex }
      let(:path)        { 'tmp/hash_index' }

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
    end
  end
end
