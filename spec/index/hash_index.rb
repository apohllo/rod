require 'bundler/setup'
require 'minitest/autorun'
require 'rod/utils'
require 'inline'
require 'rod/model/resource' #Tego tu NIE powinno być, ale jeszcze nie zastanawiałem się jak to usunąć.
require_relative '../../lib/rod/index/hash_index'
require_relative '../../lib/rod/exception'
require_relative '../spec_helper'

module Rod
  module Index
    describe HashIndex < Base do
      #dodanie tutaj :proxy_factory wywołuje BŁĄD 'can't convert nill into String'
      subject                     { Base.create(path, klass, options={:index=>:hash,:proxy_factory => proxy_factory}) }
      let(:path)                  { "tmp/hash_index" }
      let(:klass)                 { Object.new() }

      let(:proxy_factory)	{ stub(proxy_factory = Object.new).new { collection_proxy }
                                    proxy_factory
                                }
      let(:collection_proxy)    { Object.new }

      #it "must be closed on init" do
      #  subject.wont_be :opened?
      #end

      it "test1" do
        #stub(proxy_factory = Object.new).new { collection_proxy = Object.new }
        #collection_proxy = stub
        stub(collection_proxy).database { subject }
        stub(collection_proxy).key { 'abc' }

        collection_proxy.key.must_equal 'abc'
        collection_proxy.database.must_equal subject
        proxy = subject['abc']
        proxy.must_equal collection_proxy
        proxy.key.must_equal collection_proxy.key
        subject.save
      end

    end
  end
end
