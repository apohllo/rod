require 'bundler/setup'
require 'minitest/autorun'
require 'active_model/naming'

require 'rod/database/resource_metadata'
require 'rod/property/class_methods'
require 'rod/exception'
require 'rod/model/resource'
require_relative '../../spec_helper'

module Rod
  module Database
    module ResourceMetadata
      describe Resource do
        subject              { Resource.new(resource,database) }
        let(:resource)       { stub(resource = Object.new).superclass {superclass}
                               stub(resource).name { resource_name }
                               stub(resource).name_hash { name_hash }
                               stub(resource).fields { fields }
                               stub(resource).singular_associations { [] }
                               stub(resource).plural_associations { [] }
                               stub(resource).included_modules { [] }
                               resource
                             }
        let(:resource_name)  { "FirstClass" }
        let(:name_hash)      { 1234 }
        let(:fields)         { [] }
        let(:superclass)     { Object }
        let(:other)          { Resource.new(other_resource,database) }
        let(:other_resource) { stub(resource = Object.new).superclass {superclass}
                               stub(resource).name {"SecondClass"}
                               stub(resource).name_hash { 5678 }
                               stub(resource).fields { [] }
                               stub(resource).singular_associations { [] }
                               stub(resource).plural_associations { [] }
                               resource
                             }
        let(:database)       { stub(db=Object.new).count { 10 }
                               db
        }

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
          descriptor = subject.to_hash
          descriptor[:name_hash].must_equal name_hash
          descriptor[:fields].must_equal nil
        end

        it "converts hash to itself" do
          descriptor = {
            :name => resource_name,
            :name_hash => name_hash,
            :count => 10
          }
          metadata = ResourceMetadata.build(resource,database,descriptor)
          metadata.count.must_equal 10
        end
      end
    end
  end
end
