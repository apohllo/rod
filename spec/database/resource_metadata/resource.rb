require 'minitest/autorun'
require_relative '../../../lib/rod/database/resource_metadata'
require_relative '../../../lib/rod/property/class_methods'
require_relative '../../../lib/rod/exception'
require_relative '../../spec_helper'

module Rod
  module Database
    module ResourceMetadata
      describe Resource do
        subject              { Resource.new(resource,database) }
        let(:resource)       { stub(resource = Object.new).superclass {superclass}
                               stub(resource).name {"FirstClass"}
                               stub(resource).name_hash { 1234 }
                               stub(resource).fields { [] }
                               stub(resource).singular_associations { [] }
                               stub(resource).plural_associations { [] }
                               resource
                             }
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
        let(:database)       { Object.new }

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
      end
    end
  end
end
