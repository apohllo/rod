require 'bundler/setup'
require 'minitest/autorun'
require 'virtus'

require 'rod/property/virtus_adapter'

require_relative '../spec_helper'

class Person
  include Virtus

  attribute :age, Fixnum, :default => 0
  attribute :height, Float, :default => 1.7
  attribute :name, String
  attribute :surname, String, :index => :hash
  attribute :sex, Symbol
  attribute :father, Person
  attribute :item, Object
  attribute :children, Array[Person]
  attribute :items, Array[Object]
end

module Rod
  module Property
    describe VirtusAdapter do
      subject             { VirtusAdapter.new }
      let(:klass)         { Person }
      let(:resource)      { stub(resource=Object.new).field(anything,anything,anything) { }
                            stub(resource).has_one(anything,anything) { }
                            stub(resource).has_many(anything,anything) { }.subject }

      it "converts fixnum attribute" do
        subject.convert_attribute(klass.attribute_set[:age],resource)
        assert_received(resource){|o| o.field(:age,:integer,{}) }
      end

      it "converts float attribute" do
        subject.convert_attribute(klass.attribute_set[:height],resource)
        assert_received(resource){|o| o.field(:height,:float,{}) }
      end

      it "converts string attribute" do
        subject.convert_attribute(klass.attribute_set[:name],resource)
        assert_received(resource){|o| o.field(:name,:string,{}) }
      end

      it "converts an indexed attribute" do
        subject.convert_attribute(klass.attribute_set[:surname],resource)
        assert_received(resource){|o| o.field(:surname,:string,{index: :hash}) }
      end

      it "converts an object attribute" do
        subject.convert_attribute(klass.attribute_set[:sex],resource)
        assert_received(resource){|o| o.field(:sex,:object,{}) }
      end

      it "converts a singular association" do
        subject.convert_attribute(klass.attribute_set[:father],resource)
        assert_received(resource){|o| o.has_one(:father,{}) }
      end

      it "converts a singular polymorphic association" do
        subject.convert_attribute(klass.attribute_set[:item],resource)
        assert_received(resource){|o| o.has_one(:item,{:polymorphic => true}) }
      end

      it "converts a plural association" do
        subject.convert_attribute(klass.attribute_set[:children],resource)
        assert_received(resource){|o| o.has_many(:children,{}) }
      end

      it "converts a plural polymorphic association" do
        subject.convert_attribute(klass.attribute_set[:items],resource)
        assert_received(resource){|o| o.has_many(:items,{:polymorphic => true}) }
      end
    end
  end
end
