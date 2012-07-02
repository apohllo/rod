$:.unshift("lib")
require 'rod'

module RodTest
  class Model < Rod::Model::Base
  end

  %w{A B C D E}.each do |letter|
    klass = Class.new(Model) do
      10.times do |i|
        field "a#{i}".to_sym, :ulong
      end

    end
    const_set("#{letter}Struct",klass)
    klass.send(:build_structure)
  end

  class EffectivenessTest

    MAGNITUDE = 100000
    FILENAME = "tmp/eff1"

    def setup
      Model.instance.create_database(FILENAME)
      @structs = {}
      %w{A B C D E}.each do |letter|
        @structs[letter.to_sym] = []
        (MAGNITUDE).times do |i|
          @structs[letter.to_sym][i] = RodTest.const_get("#{letter}Struct").new
          10.times do |j|
            @structs[letter.to_sym][i].send("a#{j}=",j)
          end
        end
      end
    end

    def main
      start_t = Time.now.to_f
      %w{A B C D E}.each do |letter|
        (MAGNITUDE / 2).times {|i| @structs[letter.to_sym][i].store }
      end
      %w{A B C D E}.each do |letter|
        (MAGNITUDE / 2).times {|i| @structs[letter.to_sym][MAGNITUDE/2 + i].store }
      end
      end_t = Time.now.to_f
      puts "Storing the objects in the DB took #{end_t - start_t} seconds"

      start_t = Time.now.to_f
      Model.close_database
      end_t = Time.now.to_f

      puts "Closing the DB took #{end_t - start_t} seconds"
    end
  end
end

e = RodTest::EffectivenessTest.new
e.setup
e.main
