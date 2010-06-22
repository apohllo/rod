require 'lib/rod'

module RodExample

	class InnerExporter < Rod::Exporter
	  def self.create(path, classes)
	    `touch #{__FILE__}` 
	    super(path,classes)
	  end
	end

  class InnerLoader < Rod::Loader
	  def self.open(path, classes)
	    super(path,classes)
    end
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

  class Model < Rod::Model
    attr_accessor :used

		def self.exporter_class
			Exporter
		end

		def self.loader_class
			Loader 
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

  class AStruct < Model
		field :a1, :integer
		field :a2, :ulong, :index => true
    has_many :b_structs, :class_name => "RodExample::BStruct"
		
		build_structure

#	  def to_s    <- causes strange Error - see Exporter::method_missing
#		  "#{a1}, #{a2}"
#  	end
	end

    MAGNITUDE = 5
    TEST_FILENAME = "tmp/db.dat"
      
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
      
#   (0..MAGNITUDE).each do |j|
#      @as[j].b_structs = @bs[j .. ((j+1) % MAGNITUDE)]
#   end

		Model.create_database("#{TEST_FILENAME}")
    @as.each do |a|
		  a.store
		end
		@bs.each do |b|
			b.store
		end
		Model.close_database

		# verification
    Model.open_database("#{TEST_FILENAME}")
		puts "Loaded #{AStruct.count} AStruct structures."
		Model.close_database	
      
end
