require 'rod'

if ARGV.size != 3
  puts "convert_index.rb db_path class_name property"
  puts
  puts "  Converts flat to segmented index"
  puts "  db_path - the path to the database"
  puts "  class_name - the name of the class with the indexed property"
  puts "  property - the name of the indexed property"
  puts
  puts "  Don't forget to change the definition of the class after the conversion"
  exit
end

db_path, class_name, property = ARGV

Rod::Database.instance.open_database(db_path,false)
db = Rod::Database.instance
klass = class_name.split("::").inject(Object) do |mod,name|
  begin
    mod.const_get(name)
  rescue
    klass = Class.new(Rod::Model)
    mod.const_set(name,klass)
    klass
  end
end
index = db.read_index(class_name.constantize,property,{:index => :flat})
klass.instance_variable_set("@#{property}_index",index)
db.write_index(klass,property,{:index => :segmented, :rewrite => true})
#Rod::Database.instance.close_database
