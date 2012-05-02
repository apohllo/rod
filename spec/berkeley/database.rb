require 'bundler/setup'
require 'minitest/autorun'
require 'rod'

describe Rod::Berkeley::Database do
  describe "a database" do
    before do
      environment = Rod::Berkeley::Environment.new
      environment.open("tmp/env_db", :create => true, :cache => true)
      @database = Rod::Berkeley::Database.new(environment)
    end

    after do
      @database.close
      @database.environment.close
    end

    it "should not be in opened state befor being opened" do
      @database.opened?.must_equal false
    end

    it "should allow to open itself" do
      proc {@database.open("db1.db", :hash, :create => true, :truncate => true)}.must_be_silent
    end

    it "should be in opened state after being opened" do
      @database.open("db1.db", :hash, :create => true, :truncate => true)
      @database.opened?.must_equal true
    end

    it "should not allow to open itself twice" do
      @database.open("db1.db", :hash, :create => true, :truncate => true)
      proc {@database.open("db1.db", :hash, :create => true, :truncate => true)}.must_raise Rod::DatabaseError
    end

    it "should allow to close itself" do
      proc {@database.close}.must_be_silent
    end

    it "should not be in opened state after being closed" do
      @database.open("db1.db", :hash, :create => true, :truncate => true)
      @database.close
      @database.opened?.must_equal false
    end
  end

  describe "a hash database with transactions enabled" do
    before do
      environment = Rod::Berkeley::Environment.new
      environment.open("tmp/env_txn", :create => true, :cache => true, :transactions => true,
                      :logging => true, :locking => true)
      @database = Rod::Berkeley::Database.new(environment)
      @database.open("db1.db", :hash, :create => true, :auto_commit => true)
    end

    after do
      @database.close
      @database.environment.close
    end

    it "should allow to add data with transactional protection" do
      transaction = Rod::Berkeley::Transaction.new(@database.environment)
      transaction.begin
      @database.put("Ruby","Matz",transaction)
      transaction.commit

      transaction.reset
      transaction.begin
      @database.get("Ruby").must_equal "Matz"
      transaction.commit

      transaction.reset
      transaction.begin
      @database.put("Ruby","Matsumoto San",transaction)
      transaction.abort

      transaction.reset
      transaction.begin
      @database.get("Ruby").must_equal "Matz"
      transaction.commit
    end
  end
end
