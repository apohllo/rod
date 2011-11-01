require 'bundler/setup'
require 'minitest/autorun'
require 'rod'

describe Rod::Property::SingularAssociation do
  before do
    @klass = MiniTest::Mock.new
    @builder = MiniTest::Mock.new
    @klass.expect :nil?,false
  end

  after do
    @klass.verify
    @builder.verify
  end

  describe "a singular association" do
    before do
      @association = Rod::Property::SingularAssociation.new(@klass,:user,
                                                            :polymorphic => true)
    end

    it "must not be a field" do
      @association.field?.wont_equal true
    end

    it "must be an association" do
      @association.association?.must_equal true
    end

    it "must be a singular association" do
      @association.singular?.must_equal true
    end

    it "must not be a plural association" do
      @association.plural?.wont_equal true
    end

    it "must produce proper metadata" do
      @association.metadata.must_equal({:polymorphic => true})
    end

    it "must define C accessors" do
      @klass.expect :struct_name, "struct_name"
      @builder.expect :c,nil,[String]
      @association.define_c_accessors(@builder)
    end

    it "must seal C accessors" do
      @klass.expect :send,nil,[:private,String]
      @association.seal_c_accessors
    end

    it "must define getter" do
      @klass.expect :send,nil,[:define_method,"user"]
      @klass.expect :scope_name,"Rod"
      @association.define_getter
    end

    it "must define setter" do
      @klass.expect :send,nil,[:define_method,"user="]
      @association.define_setter
    end
  end
end
