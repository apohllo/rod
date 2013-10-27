require 'bundler/setup'
require 'minitest/autorun'
require 'active_model/naming'

require 'rod/metadata/resource_metadata'
require 'rod/property/class_methods'
require 'rod/utils'
require 'rod/exception'
require 'rod/model/resource'
require_relative '../spec_helper'

module Rod
  module Metadata
    describe ResourceMetadata do
      subject              { ResourceMetadata.new(resource: resource, name_converter: name_converter) }
      let(:resource)       { stub(resource = Object.new).superclass {superclass}
                             stub(resource).name { resource_name }
                             stub(resource).fields { fields }
                             stub(resource).singular_associations { [] }
                             stub(resource).plural_associations { [] }
                             stub(resource).included_modules { [] }
                             stub(resource).to_s { resource_name }
                             resource
                           }
      let(:resource_name)  { "FirstClass" }
      let(:name_hash1)     { 1234 }
      let(:name_hash2)     { 5678 }
      let(:fields)         { [] }
      let(:superclass)     { Object }
      let(:other)          { ResourceMetadata.new(resource: other_resource, name_converter: name_converter) }
      let(:other_resource) { stub(resource = Object.new).superclass {superclass}
                             stub(resource).name {"SecondClass"}
                             stub(resource).fields { [] }
                             stub(resource).singular_associations { [] }
                             stub(resource).plural_associations { [] }
                             resource
                           }
      let(:container)      { stub(container=Object.new).element_count { 10 }
                             stub(container).byte_count { 20 }
                             stub(container).monomorphic_count { 0 }
                             stub(container).polymorphic_count { 20 }
                             container
      }
      let(:name_converter) do
        stub(converter=Object.new).name_hash(resource) { name_hash1 }
        stub(converter).name_hash(other_resource) { name_hash1 }.subject
      end

      it "has its name properly set" do
        subject.name.must_equal resource.name
      end

      it "yields no difference with itself" do
        skip # move to resource metadata
        subject.difference(subject).must_be :empty?
      end

      it "is compatible with self" do
        subject.check_compatibility(subject).must_equal true
      end

      it "yields difference with different metadata" do
        skip # move to resource metadata
        subject.difference(other).wont_be :empty?
      end

      it "is not compatible with different metadata" do
        (->{subject.check_compatibility(other)}).must_raise Rod::IncompatibleClass
      end

      it "has its parent set properly" do
        subject.parent.must_equal superclass.name
      end

      it "converts itself to hash" do
        descriptor = subject.to_hash(container)
        descriptor[:name_hash].must_equal name_hash1
        descriptor[:fields].must_equal nil
      end

      it "converts hash to itself" do
        descriptor = {
          :name => resource_name,
          :name_hash => name_hash1,
          :element_count => 10
        }
        metadata = ResourceMetadata.new(descriptor: descriptor, name_converter: name_converter)
        metadata.element_count.must_equal 10
      end
    end
  end
end
