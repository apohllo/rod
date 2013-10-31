require 'rr'

class MiniTest::Unit::TestCase
  include RR::Adapters::MiniTest
end

class Minitest::SharedExamples < Module
  include Minitest::Spec::DSL
end
