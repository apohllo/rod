require 'bundler/setup'
require 'minitest/autorun'
require 'ostruct'
require 'rod/accessor/singular_accessor'
require_relative '../spec_helper'

module Rod
  module Accessor
    describe SingularAccessor do
      subject               { SingularAccessor.new(property,database,
                                                   resource_space,update_factory,property_offset) }
      let(:resource_space)  { Object.new }
      let(:update_factory)  { Object.new }
      let(:object)          { mock(object=Object.new).rod_id.times(any_times) { rod_id }
                              mock(object).account  { reference }
                              object
      }
      let(:property)        { stub(property=Object.new).name { property_name }
                              stub(property).reader { property_name }
                              stub(property).writer { property_name_equals }
                              stub(property).polymorphic? { false }
                              property
      }
      let(:rod_id)          { 1 }
      let(:element_offset)  { rod_id - 1 }
      let(:property_offset) { 0 }
      let(:property_name)   { :account }
      let(:property_name_equals) { :account= }

      describe "with nil reference" do
        let(:reference)       { nil }
        let(:database)        { mock(db=Object.new).write_ulong(element_offset,
                                                                property_offset,
                                                                0) { nil }
                                db
        }

        it "saves the nil reference to the database" do
          subject.save(object)
        end

        it "loads the nil reference from the database" do
          mock(database).read_ulong(element_offset, property_offset) { 0 }
          mock(object).account = reference

          subject.save(object)
          subject.load(object)
        end
      end

      describe "with non-nil reference" do
        let(:database)        { mock(db=Object.new).write_ulong(element_offset,
                                                                property_offset,
                                                                reference_rod_id) { nil }
                                db
        }
        let(:reference_database){ Object.new }
        let(:resource)        { Object.new }
        let(:reference)       { stub(reference = Object.new).rod_id {reference_rod_id}
                                stub(reference).new?  { false }
        }
        let(:reference_rod_id){ 2 }

        it "saves the non-nil reference to the database" do
          subject.save(object)
        end

        it "loads the non-nil reference from the database" do
          mock(object).account = reference
          mock(database).read_ulong(element_offset,property_offset) { reference_rod_id }
          mock(resource_space).database_for(resource,database) { reference_database }
          mock(reference_database).find_by_rod_id(reference_rod_id) { reference }
          mock(property).resource { resource }

          subject.save(object)
          subject.load(object)
        end
      end

      describe "with polymorphic property" do
        let(:database)        { mock(db=Object.new).write_ulong(element_offset,
                                                                property_offset,
                                                                reference_rod_id) { nil }
                                mock(db).write_ulong(element_offset, property_offset+1,
                                                     resource_hash) { nil }
                                db
        }
        let(:reference_database){ Object.new }
        let(:resource)        { Object.new }
        let(:resource_hash)   { 0xaaa }
        let(:reference)       { stub(reference = Object.new).rod_id {reference_rod_id}
                                stub(reference).new?  { false }
                                stub(reference).resource { resource }
        }
        let(:reference_rod_id){ 2 }

        before do
          stub(property).polymorphic? { true }
          stub(resource_space).name_hash(resource) { resource_hash }
        end

        it "stores the polymorphic reference" do
          subject.save(object)
        end

        it "loads the polymorphic reference" do
          mock(object).account = reference
          mock(database).read_ulong(element_offset,property_offset) { reference_rod_id }
          mock(database).read_ulong(element_offset,property_offset+1) { resource_hash }
          mock(resource_space).get(resource_hash) { resource }
          mock(resource_space).database_for(resource,database) { reference_database }
          mock(reference_database).find_by_rod_id(reference_rod_id) { reference }

          subject.save(object)
          subject.load(object)
        end
      end

      describe "with unsaved reference" do
        let(:reference)       { stub(reference = Object.new).rod_id {reference_rod_id}
                                stub(reference).new?  { true }
                                stub(reference).resource { resource }
        }
        let(:resource)        { Object.new }
        let(:reference_rod_id){ 2 }
        let(:database)        { Object.new }
        let(:reference_database) { mock(db=OpenStruct.new).
                                     register_updater(reference,is_a(Proc)) {|ref,updater| db.updater = updater  }
                                   db
        }

        before do
          mock(resource_space).database_for(resource,database) { reference_database }
        end

        it "doesn't store the useved reference until it is saved" do
          subject.save(object)
        end

        it "stores the unsaved reference in the database when it is saved" do
          mock(reference_database).update(reference) { reference_database.updater.call }
          mock(database).write_ulong(element_offset, property_offset,
                                          reference_rod_id) { nil }

          subject.save(object)
          reference_database.update(reference)
        end

        it" loads the usaved reference, after is has been saved" do
          mock(reference_database).update(reference) { reference_database.updater.call }
          mock(database).write_ulong(element_offset, property_offset,
                                          reference_rod_id) { nil }
          mock(object).account = reference
          mock(database).read_ulong(element_offset,property_offset) { reference_rod_id }
          mock(resource_space).database_for(resource,database) { reference_database }
          mock(reference_database).find_by_rod_id(reference_rod_id) { reference }
          mock(property).resource { resource }

          subject.save(object)
          reference_database.update(reference)
          subject.load(object)
        end
      end
    end
  end
end
