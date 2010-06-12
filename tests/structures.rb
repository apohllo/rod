require './lib/rod'

module Test
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
    def self.exporter_class
      Exporter
    end

    def self.loader_class
      Loader
    end
  end

  class MyStruct < Model
    field :count, :integer
    field :precision, :float
    field :identifier, :ulong
    field :title, :string, :index => true
    field :body, :string
    has_one :your_struct

    build_structure

    def to_s
      "#{self.title} #{self.body} " + 
        "count #{self.count}, precision #{self.precision}, " + 
        "identifier #{self.identifier} rod_id #{self.rod_id} " +
        "your_struct #{self.your_struct}"
    end
  end

  class YourStruct < Model
    field :counter, :integer
    has_many :his_structs
    has_many :her_structs, :class_name => "Test::HisStruct"

    build_structure

    def to_s
      "counter #{self.counter}, his structs " +
        "#{self.his_structs.map{|e| e.inde}.join("")}"
    end
  end

  class HisStruct < Model
    field :inde, :integer

    build_structure

    def to_s
      "inde #{self.inde}"
    end

    def inspect
      self.to_s
    end
  end
end
