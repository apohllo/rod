$:.unshift("lib")
require 'rod'
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

		#for tests only
		def self.page_offsets_add(id)
			@offsets = Array.new unless @offsets
			@offsets << id
		end

		def self.clear
			@offsets = []
      @used = 0
		end

		def self.id=(id)
			self.page_offsets_add(id)
		end

		def initialize(id)
			self.class.page_offsets_add(id)
		end
  end

  class AStruct < Model
		field :a, :integer

		build_structure

		def to_s
			"#{self.a}"
	  	end
	  end

	  class BStruct < Model
		field :b, :integer

		build_structure

		def to_s
			"#{self.b}"
  	end

  end

	  class CStruct < Model
		field :c, :integer

		build_structure

		def to_s
			"#{self.c}"
	  	end

	  end

	class ServiceTests < Test::Unit::TestCase

		def test_arrange_pages1
			CStruct.page_offsets

			CStruct.new(1)
			BStruct.new(2)
			AStruct.new(3)
			CStruct.new(4)
			BStruct.new(5)
			AStruct.new(6)
			BStruct.new(7)
			AStruct.new(8)
			AStruct.new(9)
			classes = [AStruct, BStruct, CStruct]
      fire_test(classes)
    end

		def test_arrange_pages2
			AStruct.page_offsets
			AStruct.new(1)
			AStruct.new(3)
			AStruct.new(6)
			BStruct.new(2)
			BStruct.new(7)
			CStruct.new(4)
			CStruct.new(5)
			classes = [AStruct, BStruct, CStruct]
      fire_test(classes)
    end

    def fire_test(classes)

			offsets = Array.new
			classes.each {|c| c.page_offsets.each {|p| offsets[p] = c}}
      offsets_initial = offsets.dup

			puts
			p offsets
			puts "=>"

			classes.each do |klass|
        #puts "beginning #{klass}..."

				klass_offsets, other_offsets, new_offsets = *Rod::Service.arrange_pages(klass, classes)
				assert(other_offsets.size == new_offsets.size, 'Should be of equal length!')
        #p [klass_offsets, other_offsets, new_offsets]

				offsets2 = offsets.dup
        start = klass_offsets[0]
				klass_offsets.each_index {|i| offsets2[i+start] = offsets[klass_offsets[i]]}

				other_offsets.each_index {|i| offsets2[new_offsets[i]] = offsets[other_offsets[i]]}

        #p offsets2
				classes.each {|c| c.clear}
				offsets2.each_index {|i| offsets2[i].id = i if offsets2[i]}
        #p classes.map {|c| c.page_offsets}

				offsets = offsets2
			end

      curr_class = Model.class

      ## validation

      # whether coherent
      offsets.each_index do |i|
        if offsets[i].class != curr_class and offsets[i] != nil
          assert(offsets[i].class.used == 0)
          curr_class.used = 1
          curr_class = offsets[i].class
        end
      end

      p offsets

      # whether same number of occurances
      freq = Hash.new(0)
      offsets[1..-1].each { |key|
        freq[key] = freq[key] + 1
      }

      freq_initial = Hash.new(0)
      offsets_initial[1..-1].each { |key|
        freq_initial[key] = freq_initial[key] + 1
      }
      assert(freq == freq_initial)

      classes.each {|c| c.clear}
		end
	end

end

