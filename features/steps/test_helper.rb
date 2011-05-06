$:.unshift "lib"
require 'rod'
module RodTest
  class Database < Rod::Database
  end

  class TestModel < Rod::Model
    database_class Database
  end
end

module RodTestSpace
end
