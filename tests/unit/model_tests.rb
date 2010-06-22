require 'lib/rod'
require 'test/unit'

module RodTest
	class Exporter < Rod::Exporter
	  def self.create(path,classes)
	    `touch #{__FILE__}` 
	    super(path,classes)
	  end
	end

  class Loader < Rod::Loader
	  def self.open(path, classes)
	    super(path,classes)
    end
  end
 
  class Model < Rod::Model
      attr_accessor :used

		def self.exporter_class
			Exporter
		end

		def self.loader_class
			Loader 
	  end

  end

  class AStruct < Model
		field :a1, :integer
		field :a2, :ulong, :index => true
    has_many :b_structs, :class_name => "RodTest::BStruct"
		
		build_structure

		def to_s
			"#{self.a1}, #{self.a2}"
	  	end
	  end

	  class BStruct < Model
		field :b, :string
	  has_one :a_struct

		build_structure

		def to_s
			"#{self.b}"
  	end

  end

	class ModuleTests < Test::Unit::TestCase

		def test_reflection
      puts
      # A

      p AStruct.fields
      assert AStruct.fields.has_key?(:a1)
      assert AStruct.fields[:a1].has_key?(:type)
      assert AStruct.fields[:a1][:type] == :integer

      assert AStruct.fields.has_key?(:a2)
      assert AStruct.fields[:a2].has_key?(:type)
      assert AStruct.fields[:a2][:type] == :ulong
      assert AStruct.fields[:a2].has_key?(:index)
      assert AStruct.fields[:a2][:index] == true

      assert AStruct.fields.has_key?("rod_id")

      p AStruct.plural_associations
      assert AStruct.plural_associations.has_key?(:b_structs)
      assert AStruct.plural_associations[:b_structs].has_key?(:class_name)
      assert AStruct.plural_associations[:b_structs][:class_name] == "RodTest::BStruct"

      # B

      p BStruct.singular_associations
      assert BStruct.singular_associations.has_key?(:a_struct)
      
      assert BStruct.fields.has_key?("rod_id")
		end

    def test_instances
      puts

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
      puts

      a1 = AStruct.new
      a2 = AStruct.new
      a3 = AStruct.new

      b1 = BStruct.new
      b2 = BStruct.new

      a1.b_structs = [b1, b2]
      a2.b_structs = [b1]
      a3.b_structs = []

      Model.create_database("tmp/test_stored_instances.dat") 
      a1.store
      a2.store
      a3.store

      b1.store
 
      p "AStruct.referenced_objects: #{AStruct.referenced_objects}"
      p "BStruct.referenced_objects: #{BStruct.referenced_objects}"
      assert a1.b_structs_count == a1.b_structs.count
      #p "AStruct.count: #{AStruct.count}" <- should throw a more relevant exception

    end

	end

end

