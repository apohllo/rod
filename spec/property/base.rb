require 'bundler/setup'
require 'minitest/autorun'
require 'rod'

describe Rod::Property::Base do
  describe "a property" do
    before do
      @klass = MiniTest::Mock.new
      @klass.expect :nil?,false
      @field = Rod::Property::Field.new(@klass,:user_name,:string)
    end

    after do
      @klass.verify
    end

    it "must have proper name" do
      @field.name.must_equal :user_name
    end

    it "must have proper type" do
      @field.type.must_equal :string
    end

    it "must produce its metadata" do
      @field.metadata.wont_be_nil
    end

    it "must covert to C struct" do
      @field.to_c_struct.wont_be_nil
    end

    it "must produce its layout" do
      @field.layout.wont_be_nil
    end

    it "must not have an index" do
      @field.has_index?.wont_equal true
    end
  end

  describe "an indexed property" do
    before do
      @klass = MiniTest::Mock.new
      @klass.expect :nil?,false
      @field = Rod::Property::Field.new(@klass,:user_name,:string,:index => :flat)
    end

    it "must have an index" do
      @field.has_index?.must_equal true
    end

    it "must return an index" do
      database = MiniTest::Mock.new
      database.expect :path,"path"
      @klass.expect :database,database
      @klass.expect :model_path,"model_path"
      @field.index.wont_be_nil
      database.verify
    end

    it "must define finders" do
      database = MiniTest::Mock.new
      database.expect :nil?,false
      database.expect :path,"path"
      @klass.expect :database,database
      @klass.expect :model_path,"model_path"
      @field.define_finders
      proc {@klass.find_by_user_name("Name")}.must_be_silent
      database.verify
    end
  end
end
