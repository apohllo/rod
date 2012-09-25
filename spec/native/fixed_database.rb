require 'bundler/setup'
require 'minitest/autorun'
require_relative '../../lib/rod/native/fixed_database'
require_relative '../../lib/rod/exception'
require_relative '../spec_helper'

module Rod
  module Native
    describe FixedDatabase do
      subject                     { FixedDatabase.new(path,element_size,element_count,
                                                    readonly) }
      let(:path)                  { "tmp/native_fixed_database.rod" }
      let(:element_size)          { 1 }
      let(:element_count)         { 5 }
      let(:readonly)              { false }

      it "must be closed on init" do
        subject.wont_be :opened?
      end

      it "doesn't accept nil path" do
        (->(){ FixedDatabase.new(nil,element_size,element_count,readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept non-string path" do
        (->(){ FixedDatabase.new(10,element_size,element_count,readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept nil element_size" do
        (->(){ FixedDatabase.new(path,nil,element_count,readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept non-numeric element_size" do
        (->(){ FixedDatabase.new(path,"abc",element_count,readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept negative element_size" do
        (->(){ FixedDatabase.new(path,-1,element_count,readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept nil element_count" do
        (->(){ FixedDatabase.new(path,element_size,nil,readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept non-numeric element_count" do
        (->(){ FixedDatabase.new(path,element_size,"abc",readonly)}).must_raise InvalidArgument
      end

      it "doesn't accept negative element_count" do
        (->(){ FixedDatabase.new(path,element_size,-1,readonly)}).must_raise InvalidArgument
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
          subject.save_integer(0,0,40)
          subject.read_integer(0,0).must_equal 40
        end
        subject.wont_be :opened?
        subject.open
        subject.read_integer(0,0).must_equal 40
        subject.close
      end

      it "truncates itself" do
        subject.open do
          subject.save_integer(0,0,60)
          subject.read_integer(0,0).must_equal 60
        end
        subject.open(:truncate => true)
        subject.read_integer(0,0).must_equal 0
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

      it "saves and reads an integer values" do
        subject.open(:truncate => true) do
          subject.save_integer(0,0,10)
          subject.read_integer(0,0).must_equal 10
          subject.save_integer(1,0,-20)
          subject.read_integer(1,0).must_equal -20
        end
      end

      it "doesn't save non-integer values as integers" do
        subject.open(:truncate => true) do
          (->(){ subject.save_integer(2,0,1.5) }).must_raise InvalidArgument
          (->(){ subject.save_integer(2,0,2 ** 65) }).must_raise InvalidArgument
          (->(){ subject.save_integer(2,0,"string") }).must_raise InvalidArgument
        end
      end

      it "saves and reads a float values" do
        subject.open(:truncate => true) do
          subject.save_float(0,0,10.1)
          subject.read_float(0,0).must_equal 10.1
          subject.save_float(1,0,20.1)
          subject.read_float(1,0).must_equal 20.1
        end
      end

      it "doesn't save non-float values as floats" do
        subject.open(:truncate => true) do
          (->(){ subject.save_float(2,0,"string") }).must_raise InvalidArgument
        end
      end

      it "saves and reads an unsigned long values" do
        subject.open(:truncate => true) do
          subject.save_ulong(0,0,2 ** 31)
          subject.read_ulong(0,0).must_equal 2 ** 31
          subject.save_ulong(1,0,2 ** 30)
          subject.read_ulong(1,0).must_equal 2 ** 30
          subject.save_ulong(2,0,0)
          subject.read_ulong(2,0).must_equal 0
        end
      end

      it "doesn't save non-ulong values as ulongs" do
        subject.open(:truncate => true) do
          (->(){ subject.save_ulong(3,0,-1) }).must_raise InvalidArgument
          (->(){ subject.save_ulong(3,0,1.5) }).must_raise InvalidArgument
          (->(){ subject.save_ulong(3,0,"string") }).must_raise InvalidArgument
        end
      end

      it "doesn't store values with invalid element offset" do
        subject.open(:truncate => true) do
          (->(){ subject.save_integer(element_count,0,1) }).must_raise InvalidArgument
          (->(){ subject.save_float(element_count,0,1.0) }).must_raise InvalidArgument
          (->(){ subject.save_ulong(element_count,0,1) }).must_raise InvalidArgument
          (->(){ subject.save_integer(-1,0,1) }).must_raise InvalidArgument
          (->(){ subject.save_float(-1,0,1.0) }).must_raise InvalidArgument
          (->(){ subject.save_ulong(-1,0,1) }).must_raise InvalidArgument
        end
      end

      it "doesn't store values with invalid property offset" do
        subject.open(:truncate => true) do
          (->(){ subject.save_integer(0,element_size,1) }).must_raise InvalidArgument
          (->(){ subject.save_float(0,element_size,1.0) }).must_raise InvalidArgument
          (->(){ subject.save_ulong(0,element_size,1) }).must_raise InvalidArgument
          (->(){ subject.save_integer(0,-1,1) }).must_raise InvalidArgument
          (->(){ subject.save_float(0,-1,1.0) }).must_raise InvalidArgument
          (->(){ subject.save_ulong(0,-1,1) }).must_raise InvalidArgument
        end
      end

      it "allocates specified number of elements" do
        subject.open(:truncate => true) do
          new_elements_count = 10
          subject.allocate_elements(new_elements_count)
          subject.save_integer(new_elements_count + element_count - 1,0,11)
          subject.read_integer(new_elements_count + element_count - 1,0).must_equal 11
        end
      end

      it "allocates large number of elements" do
        subject.open(:truncate => true) do
          new_elements_count = 100000
          subject.allocate_elements(new_elements_count)
          subject.save_integer(new_elements_count + element_count - 1,0,51)
          subject.read_integer(new_elements_count + element_count - 1,0).must_equal 51
        end
      end
    end
  end
end
