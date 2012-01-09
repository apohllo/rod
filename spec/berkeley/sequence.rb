require 'bundler/setup'
require 'minitest/autorun'
require 'rod'

describe Rod::Berkeley::Sequence do
  describe "a sequence" do
    before do
      environment = Rod::Berkeley::Environment.new
      environment.open("tmp/env_seq", :create => true, :cache => true)
      database = Rod::Berkeley::Database.new(environment)
      database.open("db1.db", :hash, :create => true, :truncate => true)
      @sequence = Rod::Berkeley::Sequence.new(database)
    end

    after do
      @sequence.close
      @sequence.database.close
      @sequence.database.environment.close
    end

    it "should allow to open itself with 'sequence' as the key" do
      proc {@sequence.open("sequence", nil, :create => true)}.must_be_silent
    end

    it "should allow to close itself" do
      @sequence.open("sequence", nil, :create => true)
      proc {@sequence.close}.must_be_silent
    end
  end

  describe "an opened sequence" do
    before do
      environment = Rod::Berkeley::Environment.new
      environment.open("tmp/env_seq", :create => true, :cache => true)
      database = Rod::Berkeley::Database.new(environment)
      database.open("db1.db", :hash, :create => true, :truncate => true)
      @sequence = Rod::Berkeley::Sequence.new(database)
      @sequence.open("sequence", nil, :create => true)
    end

    after do
      @sequence.close
      @sequence.database.close
      @sequence.database.environment.close
    end

    it "should return 1 as its first value" do
      @sequence.next.must_equal 1
    end

    it "should return 3 as the second value with delta set to 2" do
      @sequence.next(nil,:delta => 2)
      @sequence.next.must_equal 3
    end
  end

  describe "an opened sequence with large cache" do
    before do
      environment = Rod::Berkeley::Environment.new
      environment.open("tmp/env_seq_txn", :create => true, :cache => true,
                      :transactions => true, :logging => true, :locking => true)
      database = Rod::Berkeley::Database.new(environment)
      database.open("db1.db", :hash, :create => true, :auto_commit => true)
      @sequence = Rod::Berkeley::Sequence.new(database)
      @sequence.open("sequence", nil, :create => true, :cache_size => 1000)
    end

    after do
      @sequence.close
      @sequence.database.close
      @sequence.database.environment.close
    end

    it "should retrive 100 000 values fast" do
      100_000.times{ @sequence.next}
    end
  end

  describe "an opened sequence with small cache" do
    before do
      environment = Rod::Berkeley::Environment.new
      environment.open("tmp/env_seq_txn", :create => true, :cache => true,
                      :transactions => true, :logging => true, :locking => true)
      database = Rod::Berkeley::Database.new(environment)
      database.open("db1.db", :hash, :create => true, :auto_commit => true)
      @sequence = Rod::Berkeley::Sequence.new(database)
      @sequence.open("sequence", nil, :create => true)
    end

    after do
      @sequence.close
      @sequence.database.close
      @sequence.database.environment.close
    end

    it "should retrive 100 000 values fast is syncing is disabled" do
      100_000.times{ @sequence.next(nil, :no_sync => true)}
    end
  end

end
