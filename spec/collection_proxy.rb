require 'bundler/setup'
require 'minitest/autorun'
require 'rod'
require 'mocha'

# TODO translate collection proxy feature into spec.
describe Rod::CollectionProxy do
  describe "a persisted collection proxy" do
    before do
      @size = 10
      @offset = 0
      @db = Object.new
      @size.times do |index|
        @db.expects(:join_index).with(@offset,index).returns(index+1).at_least(0)
      end
      @proxy = Rod::CollectionProxy.new(@size,@db,@offset,Rod::Model)
    end

    describe "with another collection proxy" do
      before do
        size = 10
        size.times do |index|
          # these collections have 5 rod_ids in common (6 = 1 + 5, 0 for nil objects)
          @db.expects(:join_index).with(@size,index).returns(index+6).at_least(0)
        end
        @other_proxy = Rod::CollectionProxy.new(size,@db,@size,Rod::Model)
      end

      it "should be possible to compute their intersection" do
        (@proxy & @other_proxy).size.must_equal 5
      end

      it "should be possible to compute their sum" do
        (@proxy | @other_proxy).size.must_equal 15
      end
    end
  end
end
