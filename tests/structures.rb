$:.unshift("lib")
require 'rod'

module RodTest
  class Database < Rod::Native::Database
  end

  class Model < Rod::Model::Base
    database_class Database
  end

  class MyStruct < Model
    field :count, :integer
    field :precision, :float
    field :identifier, :ulong
    field :title, :string, :index => :segmented
    field :title2, :string
    field :body, :string
    has_one :your_struct

    def to_s
      "#{self.title} #{self.body} " +
        "count #{self.count}, precision #{self.precision}, " +
        "identifier #{self.identifier} rod_id #{self.rod_id} " +
        "your_struct #{self.your_struct}"
    end
  end

  class YourStruct < Model
    field :counter, :integer
    field :title, :string
    has_many :his_structs
    has_many :her_structs, :class_name => "RodTest::HisStruct"

    def to_s
      "counter #{self.counter}, title #{self.title} his structs " +
        "#{self.his_structs.map{|e| e.inde}.join("")}"
    end
  end

  class HisStruct < Model
    field :inde, :integer

    def to_s
      "inde #{self.inde}"
    end

    def inspect
      self.to_s
    end
  end
end
