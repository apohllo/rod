require 'bundler/setup'
require 'minitest/autorun'
require 'ostruct'
require 'rod/native/object_container'
require 'rod/exception'
require_relative '../spec_helper'

module Rod
  module Native
    describe Container do
      subject                               { Container.new(path,resource,db_factory,chace,readonly) }
      let(:changed_properties)              { [] }
      let(:path)                            { "tmp/natvie_object_database.rod" }
      let(:readonly)                        { false }
      let(:resource)                        { stub(resource = Object.new).new(1) { object_1 } }
      let(:object)                          { object = OpenStruct.new
                                              object.rod_id = 0
                                              object
      }
      let(:object_1)                        { object = OpenStruct.new; object.rod_id = 1 }
      let(:db_factory)                      { stub(factory = Object.new).new_fixed_database { fixed_database }
                                              stub(factory).new_flexible_database { flexible_database }
                                              factory
                                            }
      let(:fixed_database)                  { }
      let(:flexible_database)               { }
      let(:cache)                           { {} }


      it "is in closed state on init" do
        subject.wont_be :opened?
      end

      it "opens itself" do
        (->(){subject.open()}).must_be_silent
        subject.close
      end

      it "is in opened stated when opened" do
        subject.open
        subject.must_be :opened?
        subject.close
      end

      it "doesn't open itself twice" do
        subject.open()
        (->(){subject.open()}).must_raise DatabaseError
      end

      it "closes itself (even twice)" do
        subject.open
        subject.close
        subject.wont_be :opened?
        (->(){subject.close()}).must_be_silent
      end

      it "opens itself with a block and closes itself when leaving the block" do
        subject.open do
          subject.must_be :opened?
        end
        subject.wont_be :opened?
      end

      it "closes itself when block is passed, even when exception occurres" do
        id = nil
        begin
          subject.open do
            id = subject.save(object)
            raise "some exception"
          end
        rescue
        end
        subject.open
        subject.load(id).rod_id object.rod_id
        subject.load(id).rod_id id
        subject.close
      end

      it "truncates itself" do
        rod_id = nil
        subject.open(:truncate => true) do
          rod_id = subject.save(object)
        end
        subject.open do
          subject.load(rod_id).wont_be :nil?
        end
        subject.open(:truncate => true) do
          subject.load(rod_id).must_be :nil?
        end
      end

      it "updates rod_id of a new object when saving" do
        subject.open(:truncate => true) do
          object.rod_id.must_equal 0
          subject.save(object)
          object.rod_id.wont_equal 0
        end
      end

      it "retrives the same object, when it is stored and loaded via id" do
        subject.open(:truncate => true) do
          subject.save(object)
          subject.load(object.rod_id).must_equal object
        end
      end

      describe "with fixed-size changed fields" do
        let(:changed_fields)                        { field1 }
        let(:field1)                                { }
      end
    end
  end
end
