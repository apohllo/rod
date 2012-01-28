require 'bundler/setup'
require 'minitest/autorun'
require 'rod'

class User < Rod::Model
  database_class Rod::Database
end

describe Rod::Model do
  describe "a model" do
    before do
      @database = Rod::Database.instance
      @database.create_database("tmp/model")
    end

    after do
      @database.close_database
    end

    it "should return nil if index in #[] is out of scope" do
      User[0].must_equal nil
      User[1].must_equal nil
      User[-1].must_equal nil
    end
  end
end
