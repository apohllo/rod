$:.unshift("lib")
require 'rod'
require 'test/unit'

module RodTest
  class Database < Rod::Native::Database
  end

  class Model < Rod::Model::Base
    attr_accessor :used
    database_class Database
  end

  class AStruct < Model
    field :a1, :integer
    field :a2, :ulong, :index => :flat
    has_many :b_structs, :class_name => "RodTest::BStruct"

    def to_s
      "#{self.a1}, #{self.a2}"
    end
  end

  class BStruct < Model
    field :b, :string
    has_one :a_struct

    def to_s
      "#{self.b}"
    end

  end

  class ModuleTests < Test::Unit::TestCase
    def create_db
      @database = Database.instance

      @database.create_database("tmp/test_stored_instances") do
        yield
      end
    end

    def create_db_without_block
      @database = Database.instance
      @database.create_database("tmp/test_stored_instances")
    end

    def test_reflection
      # A
      create_db do
        assert AStruct.property(:a1)
        assert AStruct.property(:a1).type
        assert AStruct.property(:a1).type == :integer

        assert AStruct.property(:a2)
        assert AStruct.property(:a2).type
        assert AStruct.property(:a2).type == :ulong
        assert AStruct.property(:a2).options[:index]
        assert AStruct.property(:a2).options[:index] == :flat

        assert AStruct.property(:rod_id)

        assert AStruct.property(:b_structs)
        assert AStruct.property(:b_structs).options[:class_name]
        assert AStruct.property(:b_structs).options[:class_name] == "RodTest::BStruct"

        # B
        assert BStruct.property(:a_struct)
        assert BStruct.property(:rod_id)
      end
    end

    def test_instances
      create_db do
        a1 = AStruct.new
        a2 = AStruct.new
        a3 = AStruct.new

        b1 = BStruct.new
        b2 = BStruct.new

        # these are generated, non-trivial accessors, so they need to be tested
        a1.a1 = 2
        a1.a2 = 2000000000
        assert a1.a1 == 2
        assert a1.a2 == 2000000000

        assert a1.b_structs_count == a1.b_structs.count
        a1.b_structs = [b1, b2]
        assert a1.b_structs.to_a == [b1, b2]
        assert a1.b_structs_count == a1.b_structs.count

        b1.b = "tead-only database"
        assert b1.b == "tead-only database"
      end
    end

    def test_stored_instances
      create_db do
        a1 = AStruct.new
        a2 = AStruct.new
        a3 = AStruct.new

        b1 = BStruct.new
        b2 = BStruct.new

        a1.b_structs = [b1, b2]
        a2.b_structs = [b1]
        a3.b_structs = []

        a1.store
        a2.store
        a3.store

        b1.store
        b2.store

        assert a1.b_structs_count == a1.b_structs.count
        #p "AStruct.count: #{AStruct.count}" <- should throw a more relevant exception
      end
    end
  end
end

