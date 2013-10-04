require 'bundler/setup'
require 'minitest/autorun'

require 'rod/exception'
require 'rod/berkeley/environment'

describe Rod::Berkeley::Environment do
  describe "an environment" do
    before do
      @environment = Rod::Berkeley::Environment.new
    end

    after do
      @environment.close
    end

    it "should not be in opened state before being opened" do
      @environment.opened?.must_equal false
    end

    it "should allow to open itself" do
      proc {@environment.open("tmp/env", :create => true)}.must_be_silent
    end

    it "should not allow to open it twice" do
      @environment.open("tmp/env", :create => true)
      proc {@environment.open("tmp/env")}.must_raise Rod::DatabaseError
    end

    it "should be in opened state after being opened" do
      @environment.open("tmp/env", :create => true)
      @environment.opened?.must_equal true
    end

    it "should not be in opened state after being closed" do
      @environment.open("tmp/env", :create => true)
      @environment.close
      @environment.opened?.must_equal false
    end
  end

  describe "an opened environment" do
    before do
      @environment = Rod::Berkeley::Environment.new
      @environment.open("tmp/env", :create => true)
    end

    after do
      @environment.close
    end

    it "should be in opened state" do
      @environment.opened?.must_equal true
    end

    it "should allow to close it" do
      proc {@environment.close}.must_be_silent
    end
  end
end
