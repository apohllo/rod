def validate(index,struct)
  if struct.count != index
    raise "Invalid MyStruct#count #{struct.count}, should be #{index}" 
  end
  if struct.title != "Title_#{index}"
    raise "Invalid MyStruct#title #{struct.title}, shoud be 'Title_#{index}" 
  end
  raise "Missing MyStruct#your_struct" if struct.your_struct.nil?
  raise "Invalid YourStruct#counter" if struct.your_struct.counter != index
end

MAGNITUDO = 1000
