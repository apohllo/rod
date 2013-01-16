require 'bundler/setup'
require 'minitest/autorun'
require_relative '../../../lib/rod/database/accessor/string_accessor'
require_relative '../../../lib/rod/exception'
require_relative '../../spec_helper'

module Rod
  module Database
    module Accessor
      describe StringAccessor do
        subject               { StringAccessor.new(property,database,bytes_database) }
        let(:database)        { Object.new }
        let(:bytes_database)  { Object.new }
        let(:property)        { stub(property=Object.new).name { property_name }
                                stub(property).offset { property_offset }
                                stub(property).reader { property_name }
                                stub(property).writer { property_name_equals }
                                property
        }
        let(:property_offset) { 0 }
        let(:property_name)   { :name }
        let(:property_name_equals) { :name= }

        it "doesn't accept a nil object for writing" do
          (-> {subject.save(nil)}).must_raise InvalidArgument
        end

        it "doesn't accept a nil object for loading" do
          (-> {subject.load(nil)}).must_raise InvalidArgument
        end

        describe "with proper arguments" do
          let(:database)        { mock(db=Object.new).write_ulong(element_offset,
                                                                  property_offset,
                                                                  string_offset) { nil }
                                  mock(db).write_ulong(element_offset, property_offset+1,
                                                      string_length) { nil }
                                  db
          }
          let(:bytes_database)  { mock(db=Object.new).
                                    write_bytes(bytes_offset,string_value) { nil }
                                  mock(db).element_count { element_count }
                                  mock(db).allocate_elements(string_length) { nil }
                                  db
          }
          let(:string_value)    { "John" }
          let(:object)          { mock(object=Object.new).rod_id.times(any_times) { rod_id }
                                  mock(object).name  { string_value }
                                  object
          }
          let(:rod_id)          { 1 }
          let(:element_offset)  { rod_id - 1 }
          let(:string_offset)   { 0 }
          let(:string_length)   { string_value.bytesize }
          let(:bytes_offset)    { element_count }
          let(:element_count)   { string_offset }

          it "saves the value of a string property to the database" do
            subject.save(object)
          end


          it "loads the value of a string property from the database" do
            mock(bytes_database).read_bytes(string_offset,string_length) { string_value }
            mock(object).name = string_value
            mock(database).read_ulong(element_offset,property_offset) { string_offset }
            mock(database).read_ulong(element_offset,property_offset + 1) { string_length }

            subject.save(object)
            subject.load(object)
          end
        end
      end
    end
  end
end
