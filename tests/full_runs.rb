$:.unshift("tests")
$:.unshift("lib")
require 'structures'
require 'rod'
require 'test/unit'

module RodTest
	class FullRuns < Test::Unit::TestCase

		MAGNITUDE = 10000
		def setup
			@test_filename = "tmp/noncontinuous_pages.dat"
			Model.create_database(@test_filename)
			@hs = []
			(MAGNITUDE).times do |i|
			  @hs[i] = HisStruct.new
			  @hs[i].inde = i
			end

			@ys = []
			(MAGNITUDE).times do |i|
			  @ys[i] = YourStruct.new
			  @ys[i].counter = 10
			  @ys[i].his_structs = @hs[i*10...(i+1)*10]
			end

			@ms = []
			(MAGNITUDE * 10).times do |i|
			  @ms[i] = MyStruct.new
			  @ms[i].count = 10 * i
			  @ms[i].precision = 0.1 * i
			  @ms[i].identifier = i
			  @ms[i].your_struct = @ys[i]
			  @ms[i].title = "title_#{i}"
			  @ms[i].body = "body_#{i}"
			end
		end


		def test_noncontinuous_pages

			#creation
			(0..2).each do |j|
				@ms.each_index do |i|
					@ms[i].store if i % 3 == j
				end
				@ys.each_index do |i|
					@ys[i].store if i % 3 == j
				end
				@hs.each_index do |i|
					@hs[i].store if i % 3 == j
				end
			end
			Model.close_database

			# verification
			Model.open_database(@test_filename)
			assert MyStruct.count == @ms.count,
        "MyStruct: should be #{@ms.count}, was #{MyStruct.count}!"
			assert YourStruct.count == @ys.count,
        "YourStruct: should be #{@ys.count}, was #{YourStruct.count}!"
			assert HisStruct.count == @hs.count,
        "HisStruct: should be #{@hs.count}, was #{HisStruct.count}!"
			Model.close_database
		end
	end
end

