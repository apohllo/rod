require 'bundler/setup'
require 'minitest/autorun'
require 'rod/database/accessor/object_accessor'
require 'rod/exception'
require_relative '../../spec_helper'

module Rod
  module Database
    module Accessor
      describe ObjectAccessor do
        subject               { ObjectAccessor.new(property,database,bytes_database) }
        let(:database)        { Object.new }
        let(:bytes_database)  { Object.new }
        let(:property)        { stub(property=Object.new).name { property_name }
                                stub(property).offset { property_offset }
                                stub(property).reader { property_name }
                                stub(property).writer { property_name_equals }
                                property
        }
        let(:property_offset) { 0 }
        let(:property_name)   { :validity }
        let(:property_name_equals) { :validity= }

        it "doesn't accept a nil object for writing" do
          (-> {subject.save(nil)}).must_raise InvalidArgument
        end

        it "doesn't accept a nil object for loading" do
          (-> {subject.load(nil)}).must_raise InvalidArgument
        end

        describe "with proper arguments" do
          let(:database)        { mock(db=Object.new).write_ulong(element_offset,
                                                                  property_offset,
                                                                  object_offset) { nil }
                                  mock(db).write_ulong(element_offset, property_offset+1,
                                                      object_length) { nil }
                                  db
          }
          let(:bytes_database)  { mock(db=Object.new).
                                    write_bytes(bytes_offset,dumped_value) { nil }
                                  mock(db).element_count { element_count }
                                  mock(db).allocate_elements(object_length) { nil }
                                  db
          }
          let(:object_value)    { true }
          let(:dumped_value)    { Marshal::dump(object_value) }
          let(:object)          { mock(object=Object.new).rod_id.times(any_times) { rod_id }
                                  mock(object).validity  { object_value }
                                  object
          }
          let(:rod_id)          { 1 }
          let(:element_offset)  { rod_id - 1 }
          let(:object_offset)   { 2 }
          let(:object_length)   { dumped_value.bytesize}
          let(:bytes_offset)    { element_count }
          let(:element_count)   { object_offset }

          it "saves the value of an object property to the database" do
            subject.save(object)
          end


          it "loads the value of an object property from the database" do
            mock(bytes_database).read_bytes(object_offset,object_length) { dumped_value }
            mock(object).validity = object_value
            mock(database).read_ulong(element_offset,property_offset) { object_offset }
            mock(database).read_ulong(element_offset,property_offset + 1) { object_length }

            subject.save(object)
            subject.load(object)
          end
        end
      end
    end
  end
end
