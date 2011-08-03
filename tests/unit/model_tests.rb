$:.unshift("lib")
require 'rod'
require 'test/unit'

module RodTest
  class Database < Rod::Database
  end

  class Model < Rod::Model
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
    def setup
      Database.instance.create_database("tmp/test_stored_instances")
    end

    def teardown
      Database.instance.close_database
    end

		def test_reflection
      # A

      assert AStruct.fields.has_key?(:a1)
      assert AStruct.fields[:a1].has_key?(:type)
      assert AStruct.fields[:a1][:type] == :integer

      assert AStruct.fields.has_key?(:a2)
      assert AStruct.fields[:a2].has_key?(:type)
      assert AStruct.fields[:a2][:type] == :ulong
      assert AStruct.fields[:a2].has_key?(:index)
      assert AStruct.fields[:a2][:index] == :flat

      assert AStruct.fields.has_key?("rod_id")

      assert AStruct.plural_associations.has_key?(:b_structs)
      assert AStruct.plural_associations[:b_structs].has_key?(:class_name)
      assert AStruct.plural_associations[:b_structs][:class_name] == "RodTest::BStruct"

      # B
      assert BStruct.singular_associations.has_key?(:a_struct)

      assert BStruct.fields.has_key?("rod_id")
		end

    def test_instances
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
      assert a1.b_structs == [b1, b2]
      assert a1.b_structs_count == a1.b_structs.count

      b1.b = "tead-only database"
      assert b1.b == "tead-only database"
    end

    def test_stored_instances

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

