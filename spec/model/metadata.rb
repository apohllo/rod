require 'minitest/autorun'
require_relative '../../lib/rod/model/metadata'
require_relative '../../lib/rod/property/class_methods'
require_relative '../spec_helper'

module Rod
  module Model
    describe Metadata do
      subject           { Metadata.new(klass) }
      let(:klass)       { stub(klass = Object.new).superclass {superclass}
                          stub(klass).name {"FirstClass"}
                          klass
                        }
      let(:superclass)  { Object }
      let(:other)       { Metadata.new(other_klass) }
      let(:other_klass) { stub(klass = Object.new).superclass {superclass}
                          stub(klass).name {"SecondClass"}
                          klass
                        }

      it "acts as hash" do
        subject[:name].must_equal klass.name
      end

      it "yields no difference with itself" do
        subject.difference(subject).must_be :empty?
      end

      it "is compatible with self" do
        subject.compatible?(subject).must_equal true
      end

      it "yields difference with different metadata" do
        subject.difference(other).wont_be :empty?
      end

      it "is not compatible with different metadata" do
        subject.compatible?(other).must_equal false
      end

      describe "as hash" do
        it "has :superclass key equal to the superclass name" do
          subject[:superclass].must_equal superclass.name
        end
      end
    end
  end
end
