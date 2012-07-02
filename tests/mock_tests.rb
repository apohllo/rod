$:.unshift("lib")

require 'rod'
require 'test/unit'
require 'mocha'

module RodTest
  class InnerExporter < Rod::Exporter
  end

  class InnerLoader < Rod::Loader
  end

  class Exporter
    def self.method_missing(method_sym, *arguments)
      arguments_str = ""
      #     begin
      arguments_str = arguments.to_s
      #     rescue TypeError
      # empty is ok - thrown when trying to access fields too early
      #     end
      puts "EX: static #{method_sym.to_s} (#{arguments_str})"
      InnerExporter.send(method_sym, *arguments)
    end
  end

  class Loader
    def self.method_missing(method_sym, *arguments)
      arguments_str = arguments.to_s
      puts "LD: static #{method_sym.to_s} (#{arguments_str})"
      InnerLoader.send(method_sym, *arguments)
    end
  end

  class Database < Rod::Native::Database
  end

  class Model < Rod::Model::Base
    attr_accessor :used
    database_class Database
  end

  class BStruct < Model
    field :b, :string
    has_one :a_struct

    def to_s
      "#{self.b}"
    end

  end

  class AStruct < Model
    field :a1, :integer
    field :a2, :ulong, :index => true
    has_many :b_structs, :class_name => "RodTest::BStruct"

    #	  def to_s    <- causes strange Error - see Exporter::method_missing
    #		  "#{a1}, #{a2}"
    #  	end
  end

  class ModuleTests < Test::Unit::TestCase

    MAGNITUDE = 5
    TEST_FILENAME = "tmp/db"

    def setup
      @as = Array.new
      @bs = Array.new

      (0..MAGNITUDE).each do |j|
        @as[j] = AStruct.new
        @as[j].a1 = j
        @as[j].a2 = j * 10000
      end

      (0..MAGNITUDE).each do |j|
        @bs[j] = BStruct.new
        @bs[j].b = "string_#{j}"
        @bs[j].a_struct = @as[j]
      end

      #     (0..MAGNITUDE).each do |j|
      #        @as[j].b_structs = @bs[j .. ((j+1) % MAGNITUDE)]
      #      end
    end

    def teardown
      begin
        RodTest::Database.instance.close_database
      rescue RuntimeError
        #ok, because of mocking store subroutines not all references are marked as stored
      end
    end

    def test_store
      puts

      Database.instance.create_database("#{TEST_FILENAME}2")

      Database.instance.expects(:_store_rod_test__a_struct).times(6)
      Database.instance.expects(:_store_rod_test__b_struct).times(6)
      @as.each do |a|
        a.store
      end
      @bs.each do |b|
        b.store
      end
    end

    def test_create
      puts

      Database.instance..expects(:create)
      Database.instance.create_database("#{TEST_FILENAME}3")
    end

    def test_close
      puts

      Database.instance.create_database("#{TEST_FILENAME}4")
      Exporter.instance.expects(:close)
      Database.instance.close_database()
    end

  end
end
