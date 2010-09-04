require 'test/unit'
require 'lib/rod'
  
module RodScenario
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
    build_structure
   
    def self.exporter_class
      Exporter
    end

    def self.loader_class
      Loader
    end

    def to_s
      age.to_s
    end
  end

end

class StrightTest < Test::Unit::TestCase
  def test_whatever
    Rod::Model.create_database('tmp/fred.dat')
    f = RodScenario::Fred.new
    f.age = 2;
    f.store #<- BUG in Model:459
    id = f.rod_id
    puts id
    f = RodScenario::Fred.new
    f.age = 3;
    puts f
    Rod::Model.close_database
    Rod::Model.open_database('tmp/fred.dat')
    f = RodScenario::Fred.get(0)
    assert Rod::Model.readonly_data?
    assert f.age == 2
  end
end
