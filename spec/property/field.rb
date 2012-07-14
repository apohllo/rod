require 'bundler/setup'
require 'minitest/autorun'
require_relative '../spec_helper'
require 'rod'

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

    it "must define C accessors" do
      stub(@klass).struct_name {"struct_name"}
      stub(@builder).c(is_a(String)) {nil}
      @field.define_c_accessors(@builder)
    end

    it "must seal C accessors" do
      stub(@klass).send(:private,is_a(String)) {nil}
      @field.seal_c_accessors
    end

    it "must define getter" do
      stub(@klass).send(:define_method,"user_name") {nil}
      stub(@klass).database {nil}
      @field.define_getter
    end

    it "must define setter" do
      stub(@klass).send(:define_method,"user_name=") {nil}
      @field.define_setter
    end
  end

  describe "a string field" do
    before do
      @field = Rod::Property::Field.new(@klass,:user_name,:string)
    end

    it "must have string type" do
      @field.type.must_equal :string
    end

    it "must have empty string as default value" do
      @field.default_value.must_equal ''
    end

    it "must be a variable size field" do
      @field.variable_size?.must_equal true
    end

    it "must set utf-8 encoding for dumped value" do
      @field.dump("string").encoding.must_equal Encoding.find("utf-8")
    end

    it "must set utf-8 encoding for loaded value" do
      @field.load("string").encoding.must_equal Encoding.find("utf-8")
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

    it "must have nil as default value" do
      @field.default_value.must_equal nil
    end

    it "must be a variable size field" do
      @field.variable_size?.must_equal true
    end

    it "must marshal dumped value" do
      @field.dump(:value).must_equal Marshal::dump(:value)
    end

    it "must unmarshal loaded value" do
      @field.load(Marshal::dump(:value)).must_equal :value
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

    it "must have nil as default value" do
      @field.default_value.must_equal nil
    end

    it "must be a variable size field" do
      @field.variable_size?.must_equal true
    end

    it "must convert to json dumped value" do
      @field.dump("value").must_equal JSON::dump(["value"])
    end

    it "must convert from json loaded value" do
      @field.load(JSON::dump(["value"])).must_equal "value"
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

    it "must have 0 as default value" do
      @field.default_value.must_equal 0
    end

    it "must not be a variable size field" do
      @field.variable_size?.wont_equal true
    end

    it "must pass dumped value" do
      @field.dump(-10).must_equal -10
    end

    it "must pass loaded value" do
      @field.load(-10).must_equal -10
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

    it "must have 0.0 as default value" do
      @field.default_value.must_equal 0.0
    end

    it "must not be a variable size field" do
      @field.variable_size?.wont_equal true
    end

    it "must pass dumped value" do
      @field.dump(-10.0).must_equal -10.0
    end

    it "must pass loaded value" do
      @field.load(-10.0).must_equal -10.0
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

    it "must have 0 as default value" do
      @field.default_value.must_equal 0
    end

    it "must not be a variable size field" do
      @field.variable_size?.wont_equal true
    end

    it "must pass dumped value if it is greater or equals 0" do
      @field.dump(10.0).must_equal 10.0
      @field.dump(0).must_equal 0
    end

    it "must raise exception when dumping value lower than 0" do
      proc {@field.dump(-10)}.must_raise Rod::InvalidArgument
    end

    it "must pass loaded value" do
      @field.load(10).must_equal 10
    end

    it "must correctly convert to hash" do
      @field.to_hash.must_equal({:type => :ulong})
    end
  end
end
