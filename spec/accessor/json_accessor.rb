require 'bundler/setup'
require 'minitest/autorun'
require 'rod/accessor/json_accessor'
require 'rod/exception'
require_relative '../spec_helper'

module Rod
  module Accessor
    describe JsonAccessor do
      subject               { JsonAccessor.new(property,database,bytes_database,property_offset) }
      let(:database)        { Object.new }
      let(:bytes_database)  { Object.new }
      let(:property)        { stub(property=Object.new).name { property_name }
                              stub(property).reader { property_name }
                              stub(property).writer { property_name_equals }
                              property
      }
      let(:property_offset) { 0 }
      let(:property_name)   { :positions }
      let(:property_name_equals) { :positions= }

      it "doesn't accept a nil object for writing" do
        (-> {subject.save(nil)}).must_raise InvalidArgument
      end

      it "doesn't accept a nil object for loading" do
        (-> {subject.load(nil)}).must_raise InvalidArgument
      end

      describe "with proper arguments" do
        let(:database)        { mock(db=Object.new).write_ulong(element_offset,
                                                                property_offset,
                                                                json_offset) { nil }
                                mock(db).write_ulong(element_offset, property_offset+1,
                                                    json_length) { nil }
                                db
        }
        let(:bytes_database)  { mock(db=Object.new).
                                  write_bytes(bytes_offset,dumped_value) { nil }
                                mock(db).element_count { element_count }
                                mock(db).allocate_elements(json_length) { nil }
                                db
        }
        let(:json_value)      { [1,2,3] }
        let(:dumped_value)    { JSON::dump(json_value) }
        let(:object)          { mock(object=Object.new).rod_id.times(any_times) { rod_id }
                                mock(object).positions  { json_value }
                                object
        }
        let(:rod_id)          { 1 }
        let(:element_offset)  { rod_id - 1 }
        let(:json_offset)     { 1 }
        let(:json_length)     { dumped_value.bytesize }
        let(:bytes_offset)    { element_count }
        let(:element_count)   { json_offset }

        it "saves the value of a json property to the database" do
          subject.save(object)
        end


        it "loads the value of a json property from the database" do
          mock(bytes_database).read_bytes(json_offset,json_length) { dumped_value }
          mock(object).positions = json_value
          mock(database).read_ulong(element_offset,property_offset) { json_offset }
          mock(database).read_ulong(element_offset,property_offset + 1) { json_length }

          subject.save(object)
          subject.load(object)
        end
      end
    end
  end
end
