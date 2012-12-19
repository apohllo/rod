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
      subject                     { Base.create(path, klass, options={:index=>:hash,:proxy_factory=>proxy_factory}) }
      let(:path)                  { "tmp/hash_index" }
      let(:klass)                 { Object.new() }      
      let(:proxy_factory)					{ stub(proxy_factory = Object.new).new { collection_proxy } 
                                    proxy_factory
                                  }
      let(:collection_proxy)    	{ Object.new }

#      it "test1" do
#        stub(collection_proxy).database { subject }
#        stub(collection_proxy).key { 'abc' }

#        collection_proxy.key.must_equal 'abc'
#        collection_proxy.database.must_equal subject
#        proxy = subject['abc']
#        proxy.must_equal collection_proxy
#        proxy.key.must_equal collection_proxy.key
#        subject.save
#      end

      it "must be closed on init" do
        subject.wont_be :opened?
      end
      
      it "must be opened after init" do
        subject['abc']
        subject.must_be :opened?
      end
      
      it "must be closed after saving" do
        subject['abc']
        subject.must_be :opened?
        subject.save
        subject.wont_be :opened?
      end
     
#Not sure if the 'block' is correctly written, because the test fails.
      it "closes the database even if an exception is thrown in the block" do
        subject['abc']
        begin
          raise "some exception"
        rescue
          subject.wont_be :opened?
        end
      end

      it "doesn't accept nil, numeric or non-numeric index" do
        (->(){ Base.create(path, klass, options={:index=>nil, :proxy_factory=>proxy_factory})}).must_raise RodException
        (->(){ Base.create(path, klass, options={:index=>10, :proxy_factory=>proxy_factory})}).must_raise RodException
        (->(){ Base.create(path, klass, options={:index=>'abc', :proxy_factory=>proxy_factory})}).must_raise RodException
      end

      it "allows :hash index" do
        (->(){ Base.create(path, klass, options={:index=>:hash, :proxy_factory=>proxy_factory})}).must_be_silent
      end

#how to name this?
#is this test written correctly?
      it "" do
        stub(proxy_factory = Object.new).new {collection_proxy}
        stub(collection_proxy).database { subject }
        stub(collection_proxy).key { 'abc' }

        returned_collection = subject['abc']
        returned_collection.database.must_equal subject
        returned_collection.key.must_equal 'abc'
        subject.save
      end

#Is test below correctly written, because I'm not sure if the index was actually copied or the test passes only because it uses the same variable #line93
      it "copy" do
        stub(proxy_factory = Object.new).new {collection_proxy}
        stub(collection_proxy).database { subject }
        stub(collection_proxy).key { 'bcd' }

        subject['bcd']
        index_new = Base.create('tmp/some_path', 'class', options={:index=>:hash, :proxy_factory=>proxy_factory})
        # should 'copy' function be used like in the line below?
        index_new = index_new.copy(subject)
        index_new.klass.must_equal subject.klass
      end

#DB_NOTFOUND: No matching key/data pair found
      it "get_first" do
        stub(proxy_factory = Object.new).new {collection_proxy}
        stub(collection_proxy).database { subject }
        stub(collection_proxy).key { 'abc' }

        subject['abc']
        subject.get_first('abc')
      end
      
    end
  end
end
