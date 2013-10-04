require 'bundler/setup'
require 'minitest/autorun'
require 'rod/database/accessor/ulong_accessor'
require 'rod/exception'
require_relative '../../spec_helper'

module Rod
  module Database
    module Accessor
      describe UlongAccessor do
        subject               { UlongAccessor.new(property,database) }
        let(:database)        { Object.new }
        let(:ulong_value)     { 1 }
        let(:property_offset) { 0 }
        let(:object)          { mock(object=Object.new).rod_id.times(any_times) { rod_id }
                                mock(object).serial  { ulong_value }
                                object
        }
        let(:property)        { stub(property=Object.new).name { property_name }
                                stub(property).offset { property_offset }
                                stub(property).reader { property_name }
                                stub(property).writer { property_name_equals }
                                property
        }
        let(:rod_id)          { 1 }
        let(:element_offset)  { rod_id - 1 }
        let(:property_name)   { :serial }
        let(:property_name_equals) { :serial= }

        it "saves the value of an integer property to the database" do
          mock(database).write_ulong(element_offset, property_offset,
                                       ulong_value) { nil }
          subject.save(object)
        end

        it "doesn't accept a nil object for writing" do
          (-> {subject.save(nil)}).must_raise InvalidArgument
        end

        it "doesn't accept a nil object for loading" do
          (-> {subject.load(nil)}).must_raise InvalidArgument
        end

        it "loads the value of an integer property from the database" do
          mock(database).write_ulong(element_offset, property_offset,
                                       ulong_value) { nil }
          mock(database).read_ulong(element_offset,property_offset) { ulong_value }
          mock(object).serial = ulong_value

          subject.save(object)
          subject.load(object)
        end
      end
    end
  end
end
