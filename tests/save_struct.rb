require 'tests/structures'

puts "-- Save sample structures test --"
RodTest::Model.create_database("tmp/abc.dat")

#MAGNITUDE = 100000
MAGNITUDE = 50

his = []
(MAGNITUDE * 10).times do |i|
  his[i] = RodTest::HisStruct.new
  his[i].inde = i
end

ys = []
(MAGNITUDE * 1).times do |i|
  ys[i] = RodTest::YourStruct.new
  ys[i].counter = 10
  ys[i].his_structs = his[i*10...(i+1)*10] 
end

ms = []
(MAGNITUDE * 1).times do |i|
  ms[i] = RodTest::MyStruct.new
  ms[i].count = 10 * i
  ms[i].precision = 0.1 * i
  ms[i].identifier = i
  ms[i].your_struct = ys[i]
  ms[i].title = "title_#{i}"
  ms[i].title2 = "title2_#{i}"
  ms[i].body = "body_#{i}"
end

RodTest::Model.print_layout
ms.each_with_index{|s,i| 
  begin 
    puts i if i % 1000 == 0
    s.store
  rescue Exception => e
    puts e
    raise
  end
}
ys.each{|y| y.store}
his.each{|h| h.store}
RodTest::Model.print_layout
RodTest::Model.close_database
