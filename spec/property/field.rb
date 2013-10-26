require 'bundler/setup'
require 'minitest/autorun'
require_relative '../spec_helper'

require 'rod/property/field'

describe Rod::Property::Field do
  before do
    @klass = stub
  end

  describe "a generic field" do
    before do
      @builder = stub
      @field = Rod::Property::Field.new(@klass,:user_name,:string)
    end

    it "must be a field" do
      @field.field?.must_equal true
    end

    it "must not be an association" do
      @field.association?.wont_equal true
    end

  end

  describe "a string field" do
    before do
      @field = Rod::Property::Field.new(@klass,:user_name,:string)
    end

    it "must have string type" do
      @field.type.must_equal :string
    end

    it "must be a variable size field" do
      @field.variable_size?.must_equal true
    end

    it "must not be an identifier" do
      @field.identifier?.wont_equal true
    end

    it "must correctly convert to hash" do
      @field.to_hash.must_equal({:type => :string})
    end
  end

  describe "an object field" do
    before do
      @field = Rod::Property::Field.new(@klass,:tag,:object)
    end

    it "must have object type" do
      @field.type.must_equal :object
    end

    it "must be a variable size field" do
      @field.variable_size?.must_equal true
    end

    it "must correctly convert to hash" do
      @field.to_hash.must_equal({:type => :object})
    end
  end

  describe "a json field" do
    before do
      @field = Rod::Property::Field.new(@klass,:tag,:json)
    end

    it "must have json type" do
      @field.type.must_equal :json
    end

    it "must be a variable size field" do
      @field.variable_size?.must_equal true
    end

    it "must correctly convert to hash" do
      @field.to_hash.must_equal({:type => :json})
    end
  end

  describe "an integer field" do
    before do
      @field = Rod::Property::Field.new(@klass,:tag,:integer)
    end

    it "must have integer type" do
      @field.type.must_equal :integer
    end

    it "must not be a variable size field" do
      @field.variable_size?.wont_equal true
    end

    it "must correctly convert to hash" do
      @field.to_hash.must_equal({:type => :integer})
    end
  end

  describe "a float field" do
    before do
      @field = Rod::Property::Field.new(@klass,:tag,:float)
    end

    it "must have float type" do
      @field.type.must_equal :float
    end

    it "must not be a variable size field" do
      @field.variable_size?.wont_equal true
    end

    it "must correctly convert to hash" do
      @field.to_hash.must_equal({:type => :float})
    end
  end

  describe "an ulong field" do
    before do
      @field = Rod::Property::Field.new(@klass,:tag,:ulong)
    end

    it "must have ulong type" do
      @field.type.must_equal :ulong
    end

    it "must not be a variable size field" do
      @field.variable_size?.wont_equal true
    end

    it "must correctly convert to hash" do
      @field.to_hash.must_equal({:type => :ulong})
    end
  end
end
