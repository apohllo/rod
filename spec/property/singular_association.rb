require 'bundler/setup'
require 'minitest/autorun'
require_relative '../spec_helper'

require 'active_model/naming'
require 'rod/property/singular_association'

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
  end
end
