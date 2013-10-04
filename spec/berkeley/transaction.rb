require 'bundler/setup'
require 'minitest/autorun'

require 'rod/exception'
require 'rod/berkeley/environment'
require 'rod/berkeley/transaction'

describe Rod::Berkeley::Transaction do
  describe "a transaction" do
    before do
      environment = Rod::Berkeley::Environment.new
      environment.open("tmp/env_txn", :create => true, :cache => true, :transactions => true,
                      :logging => true, :locking => true)
      @transaction = Rod::Berkeley::Transaction.new(environment)
    end

    after do
      @transaction.finish
      @transaction.environment.close
    end

    it "should not be in started state after creation" do
      @transaction.started?.must_equal false
    end

    it "should not be in finished state after creation" do
      @transaction.finished?.must_equal false
    end

    it "should allow to start itself" do
      proc {@transaction.begin}.must_be_silent
    end

    it "should allow to start itself in no_sync mode" do
      proc {@transaction.begin(:no_sync => true)}.must_be_silent
    end

    it "should allow to start itself in sync mode" do
      proc {@transaction.begin(:sync => true)}.must_be_silent
    end

    it "should allow to start itself in write_no_sync mode" do
      proc {@transaction.begin(:write_no_sync => true)}.must_be_silent
    end

    it "should be in started state after being started" do
      @transaction.begin
      @transaction.started?.must_equal true
    end

    it "should not be in finished state after being started" do
      @transaction.begin
      @transaction.finished?.must_equal false
    end

    it "should be in started state after being committed" do
      @transaction.begin
      @transaction.commit
      @transaction.started?.must_equal true
    end

    it "should be in finished state after being committed" do
      @transaction.begin
      @transaction.commit
      @transaction.finished?.must_equal true
    end

    it "should be in started state after being aborted" do
      @transaction.begin
      @transaction.abort
      @transaction.started?.must_equal true
    end

    it "should be in finished state after being aborted" do
      @transaction.begin
      @transaction.abort
      @transaction.finished?.must_equal true
    end

    it "should allow to reset itself before being started" do
      proc {@transaction.reset}.must_be_silent
    end

    it "should allow to reset itself after being finished" do
      @transaction.begin
      @transaction.abort
      proc {@transaction.reset}.must_be_silent
    end

    it "should not allow to reset itself before being finished" do
      @transaction.begin
      proc {@transaction.reset}.must_raise Rod::DatabaseError
    end
  end
end
