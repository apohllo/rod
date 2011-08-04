$:.unshift("lib")
require 'test/unit'
require 'rod'

class CollectionProxyTest < Test::Unit::TestCase
  def test_empty?
    collection = Rod::CollectionProxy.new(0,nil,0,nil)
    assert(collection.empty?)
    item = Object.new
    def item.rod_id
      0
    end
    collection << item
    assert(!collection.empty?)
  end
end
