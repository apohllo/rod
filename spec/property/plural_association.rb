require 'bundler/setup'
require 'minitest/autorun'
require 'rod'

describe Rod::Property::PluralAssociation do
  before do
    @klass = MiniTest::Mock.new
    @builder = MiniTest::Mock.new
    @klass.expect :nil?,false
  end

  after do
    @klass.verify
    @builder.verify
  end

  describe "a plural association" do
    before do
      @association = Rod::Property::PluralAssociation.new(@klass,:users,
                                                         :polymorphic => true)
    end

    it "must not be a field" do
      @association.field?.wont_equal true
    end

    it "must be an association" do
      @association.association?.must_equal true
    end

    it "must not be a singular association" do
      @association.singular?.wont_equal true
    end

    it "must be a plural association" do
      @association.plural?.must_equal true
    end

    it "must produce proper metadata" do
      @association.metadata.must_equal({:polymorphic => true})
    end

    it "must define C accessors" do
      @klass.expect :struct_name, "struct_name"
      @klass.expect :struct_name, "struct_name"
      @klass.expect :struct_name, "struct_name"
      @klass.expect :struct_name, "struct_name"
      @builder.expect :c,nil,[String]
      @builder.expect :c,nil,[String]
      @builder.expect :c,nil,[String]
      @builder.expect :c,nil,[String]
      @association.define_c_accessors(@builder)
    end

    it "must seal C accessors" do
      @klass.expect :send,nil,[:private,String]
      @klass.expect :send,nil,[:private,String]
      @klass.expect :send,nil,[:private,String]
      @klass.expect :send,nil,[:private,String]
      @association.seal_c_accessors
    end

    it "must define getter" do
      @klass.expect :send,nil,[:define_method,"users"]
      @klass.expect :send,nil,[:define_method,"users_count"]
      @klass.expect :scope_name,"Rod"
      @klass.expect :database, nil
      @association.define_getter
    end

    it "must define setter" do
      @klass.expect :send,nil,[:define_method,"users="]
      @association.define_setter
    end
  end
end

