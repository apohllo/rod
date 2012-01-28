require 'bundler/setup'
require 'minitest/autorun'
require 'rod'

describe Rod::Database do
  describe "a database" do
    it "should allow to create itself without a block given" do
      database = Rod::Database.instance
      database.opened?.must_equal false
      database.create_database("tmp/without_block")
      database.opened?.must_equal true
      database.close_database
      database.opened?.must_equal false
    end

    it "should allow to create itself with a block given" do
      database = Rod::Database.instance
      database.opened?.must_equal false
      database.create_database("tmp/without_block") do
        database.opened?.must_equal true
      end
      database.opened?.must_equal false
    end

    it "should close itself on create even if an exception is raised" do
      database = Rod::Database.instance
      (proc do
        database.create_database("tmp/block_exception") do
          database.opened?.must_equal true
          raise "Runtime exception"
        end
      end).must_raise RuntimeError
      database.opened?.must_equal false
    end
  end
end
