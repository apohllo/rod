$:.unshift "lib"
require 'rod'

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

end
