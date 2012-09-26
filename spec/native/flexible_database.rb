# encoding: utf-8

require 'bundler/setup'
require 'minitest/autorun'
require_relative '../../lib/rod/native/flexible_database'
require_relative '../../lib/rod/exception'
require_relative '../spec_helper'

module Rod
  module Native
    describe FlexibleDatabase do
      subject                     { FlexibleDatabase.new(path,element_count,readonly) }
      let(:path)                  { "tmp/native_flexible_database.rod" }
      let(:element_count)         { 100 }
      let(:readonly)              { false }

      it "must be closed on init" do
        subject.wont_be :opened?
      end

      it "doesn't accept nil path" do
        (->(){ FlexibleDatabase.new(nil,element_count,readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept non-string path" do
        (->(){ FlexibleDatabase.new(10,element_count,readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept nil element_count" do
        (->(){ FlexibleDatabase.new(path,nil,readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept non-numeric element_count" do
        (->(){ FlexibleDatabase.new(path,"abc",readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept negative element_count" do
        (->(){ FlexibleDatabase.new(path,-1,readonly)}).must_raise InvalidArgument
      end

      it "must allow to open itself" do
        (->() { subject.open }).must_be_silent
      end

      it "is in opened state after being opened" do
        subject.open
        subject.must_be :opened?
      end

      it "is in closed state after being opened and closed" do
        subject.open
        subject.close
        subject.wont_be :opened?
      end

      it "doesn't open itself twice" do
        subject.open
        (->() { subject.open }).must_raise DatabaseError
        subject.close
      end

      it "closes itself twice" do
        subject.open
        subject.close
        (->() { subject.close }).must_be_silent
      end

      it "allows to pass a block to open" do
        subject.open(:truncate => true) do
          subject.must_be :opened?
          subject.write_bytes(0,"abc")
          subject.read_bytes(0,3).must_equal "abc"
        end
        subject.wont_be :opened?
        subject.open
        subject.read_bytes(0,3).must_equal "abc"
        subject.close
      end

      it "truncates itself" do
        subject.open do
          subject.write_bytes(0,"xyz")
          subject.read_bytes(0,3).must_equal "xyz"
        end
        subject.open(:truncate => true)
        subject.read_bytes(0,1).must_equal "\x00"
        subject.close
      end

      it "closes the database even if an exception is thrown in the block" do
        begin
          subject.open do
            raise "some exception"
          end
        rescue
          subject.wont_be :opened?
        end
      end

      it "writes and reads byte sequences" do
        subject.open(:truncate => true) do
          subject.write_bytes(0,"abc")
          subject.read_bytes(0,3).must_equal "abc"
        end
      end

      it "writes and reads byte sequences with zeros" do
        subject.open(:truncate => true) do
          subject.write_bytes(0,"\x00abc")
          subject.read_bytes(0,4).must_equal "\x00abc"
        end
      end

      it "writes and reads strings with utf-8 codes" do
        subject.open(:truncate => true) do
          subject.write_bytes(0,"ąęć")
          subject.read_bytes(0,"ąęć".bytesize).force_encoding("utf-8").must_equal "ąęć"
        end
      end

      it "doesn't write non-byte sequence values as byte sequences" do
        subject.open(:truncate => true) do
          (->(){ subject.write_bytes(2,1.5) }).must_raise InvalidArgument
          (->(){ subject.write_bytes(2,2 ** 65) }).must_raise InvalidArgument
          (->(){ subject.write_bytes(2,-5) }).must_raise InvalidArgument
        end
      end

      it "allocates specified number of elements" do
        subject.open(:truncate => true) do
          new_elements_count = 10
          subject.allocate_elements(new_elements_count)
          subject.write_bytes(new_elements_count + element_count - 1,"t")
          subject.read_bytes(new_elements_count + element_count - 1,1).must_equal "t"
        end
      end

      it "allocates large number of elements" do
        subject.open(:truncate => true) do
          new_elements_count = 100000
          subject.allocate_elements(new_elements_count)
          subject.write_bytes(new_elements_count + element_count - 1,"g")
          subject.read_bytes(new_elements_count + element_count - 1,1).must_equal "g"
        end
      end
    end
  end
end
