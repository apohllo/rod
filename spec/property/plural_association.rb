require 'bundler/setup'
require 'minitest/autorun'
require_relative '../spec_helper'

require 'active_model/naming'
require 'english/inflect'
require 'rod/property/plural_association'

describe Rod::Property::PluralAssociation do
  before do
    @klass = stub
    @builder = stub
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

    it "must correctly converter to hash" do
      @association.to_hash.must_equal({:polymorphic => true})
    end
  end
end
