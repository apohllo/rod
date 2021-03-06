require 'bundler/setup'
require 'minitest/autorun'
require_relative "../spec_helper"

require 'rod/property/base'
require 'rod/index/base'
require 'rod/index/flat_index'
require 'rod/native/collection_proxy'
require 'rod/property/field'
require 'rod/model/resource'

describe Rod::Property::Base do
  describe "a property" do
    before do
      @klass = stub
      @field = Rod::Property::Field.new(@klass,:user_name,:string)
    end

    it "must have proper name" do
      @field.name.must_equal :user_name
    end

    it "must have proper type" do
      @field.type.must_equal :string
    end

    it "must produce its metadata" do
      @field.to_hash.wont_be_nil
    end

    it "must not have an index" do
      @field.has_index?.wont_equal true
    end
  end

  describe "an indexed property" do
    before do
      @klass = stub
      @field = Rod::Property::Field.new(@klass,:user_name,:string,:index => :flat)
    end

    it "must have an index" do
      @field.has_index?.must_equal true
    end

    it "must return an index" do
      skip
      stub(database = Object.new).path {"path"}
      stub(@klass).database {database}
      stub(@klass).model_path {"model_path"}
      @field.index.wont_be_nil
    end

    it "must define finders" do
      skip
      database = stub
      stub(database).path {"path"}
      stub(@klass).database {database}
      stub(@klass).model_path {"model_path"}
      @field.define_finders
      proc {@klass.find_by_user_name("Name")}.must_be_silent
    end
  end
end
