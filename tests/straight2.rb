require 'test/unit'
require 'lib/rod'

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

  class Fred < Rod::Model
    field :age, :integer
    field :sex, :string, :index => true

    build_structure

    def self.exporter_class
      Exporter
    end

    def self.loader_class
      Loader 
    end

    def to_s
      "[#{sex}, #{age.to_s}-year old Fred]"
    end
  end

  class Stright2 < Test::Unit::TestCase

    def test_one 
      Rod::Model.create_database('tmp/fred.dat')

      f = Fred.new
      f.age = 18
      f.sex = "female"
      f.store
      f = Fred.new
      f.age = 18
      f.sex = "male"
      f.store
      f = Fred.new
      f.age = 18
      f.sex = "female"
      f.store

      Rod::Model.close_database
      Rod::Model.open_database('tmp/fred.dat')

      puts "BEFORE"
      Fred.each {|fred|
        puts fred
      }
      puts "males: #{Fred.find_all_by_sex("male")}"
      puts "females: #{Fred.find_all_by_sex("female")}"

      assert_equal 1, Fred.find_all_by_sex("male").count
      assert_equal 2, Fred.find_all_by_sex("female").count

      ###

      Rod::Model.close_database
      Rod::Model.create_database('tmp/fred2.dat')

      f = Fred.new
      f.age = 19
      f.sex = "male"
      f.store
      f = Fred.new
      f.age = 19
      f.sex = "male"
      f.store
      f = Fred.new
      f.age = 19
      f.sex = "female"
      f.store

      Rod::Model.close_database
      Rod::Model.open_database('tmp/fred2.dat')

      puts
      puts "AFTER"

      Fred.each {|fred|
        puts fred
      }
      puts "males: #{Fred.find_all_by_sex("male")}"
      puts "females: #{Fred.find_all_by_sex("female")}"

      assert_equal 2, Fred.find_all_by_sex("male").size
      assert_equal 1, Fred.find_all_by_sex("female").size
    end
  end

end
