require 'bundler/setup'
require 'minitest/autorun'
require 'rod/utils'
require 'inline'
require 'rod/model/resource' #Tego tu NIE powinno być, ale jeszcze nie zastanawiałem się jak to usunąć.
require_relative '../../lib/rod/index/hash_index'
require_relative '../../lib/rod/index/segmented_index'
require_relative '../../lib/rod/exception'
require_relative '../spec_helper'

module Rod
  module Index
    describe Base do
      subject                     { Base.create(path, klass, options={:index=>:hash,:proxy_factory=>proxy_factory}) }
      let(:path)                  { "tmp/hash_index" }
      let(:klass)                 { Object.new() }      
      let(:proxy_factory)					{ stub(proxy_factory = Object.new).new { collection_proxy } 
                                    proxy_factory
                                  }
      let(:collection_proxy)    	{ Object.new }
      
      it "doesn't accept nil, numeric or non-numeric index" do
        (->(){ Base.create(path, klass, options={:index=>nil, :proxy_factory=>proxy_factory})}).must_raise RodException
        (->(){ Base.create(path, klass, options={:index=>10, :proxy_factory=>proxy_factory})}).must_raise RodException
        (->(){ Base.create(path, klass, options={:index=>'abc', :proxy_factory=>proxy_factory})}).must_raise RodException
      end

      it "allows to create :hash type index" do
        (->(){ Base.create(path, klass, options={:index=>:hash, :proxy_factory=>proxy_factory})}).must_be_silent
      end
       
    end
  end
end
