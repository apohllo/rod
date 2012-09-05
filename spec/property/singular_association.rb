require 'bundler/setup'
require 'minitest/autorun'
require_relative '../spec_helper'
require 'rod'

describe Rod::Property::SingularAssociation do
  before do
    @klass = stub
    @builder = stub
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

    it "must correctly convert to hash" do
      @association.to_hash.must_equal({:polymorphic => true})
    end

    it "must define C accessors" do
      stub(@klass).struct_name {"struct_name"}
      stub(@builder).c(is_a(String)) {nil}
      @association.define_c_accessors(@builder)
    end

    it "must seal C accessors" do
      stub(@klass).send(:private,is_a(String)) {nil}
      @association.seal_c_accessors
    end

    it "must define getter" do
      stub(@klass).send(:define_method,"user") {nil}
      stub(@klass).parent_name {"Rod"}
      @association.define_getter
    end

    it "must define setter" do
      stub(@klass).send(:define_method,"user=") {nil}
      @association.define_setter
    end
  end
end
