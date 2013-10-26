Given /^the class space is cleared$/ do
  RodTest.constants.each do |constant|
    klass = RodTest.const_get(constant)
    RodTest.send(:remove_const,constant)
  end
  Rod::Database::Registry.instance.clear
  Rod::Model::ResourceSpace.instance.clear
end
