require 'bundler/setup'
require 'minitest/autorun'

require 'rod/database/registry'
require 'rod/exception'
require_relative '../spec_helper'

module Rod
  module Database
    describe Registry do
      subject               { Registry.instance }
      let(:db1)             { stub(db=Object.new).containers { [] }
                              stub(db).id { db1_id }.subject }
      let(:db2)             { stub(db=Object.new).containers { [] }
                              stub(db).id { db2_id }.subject }
      let(:db1_id)          { :db1 }
      let(:db2_id)          { :db2 }
      let(:resource1)       { Object.new }
      let(:resource2)       { Object.new }

      after { subject.clear }


      it "registers a database" do
        subject.register_database(db1)
        subject.find_database_by_id(db1_id).must_equal db1
      end

      it "removes a database" do
        subject.register_database(db1)
        subject.register_database(db2)
        subject.remove_database(db1_id)
        subject.find_database_by_id(db1_id).must_equal nil
        subject.find_database_by_id(db2_id).must_equal db2
      end

      it "registers default database for a resource" do
        subject.register_resource(db1_id,resource1)
        subject.database_id_for_resource(resource1).must_equal db1_id
      end

      describe "with a registered database" do
        before { subject.register_database(db1) }

        it "finds a database for a registered resource" do
          subject.register_resource(db1_id,resource1)
          subject.find_database_by_resource(resource1).must_equal db1
        end

        it "returns all resources registered for a given database id" do
          subject.register_resource(db1_id,resource1)
          subject.register_resource(db1_id,resource2)
          subject.resources_for(db1_id).must_equal [resource1,resource2]
        end

        it "keeps the resources list when the db is removed" do
          subject.register_resource(db1_id,resource1)
          subject.register_resource(db1_id,resource2)
          subject.remove_database(db1_id)
          subject.resources_for(db1_id).must_equal [resource1,resource2]
        end

      end

      describe "with a database holding containers" do
        let(:db1)         { stub(db=Object.new).containers { [container1, container2] }
                            stub(db).id { db1_id }.subject }
        let(:resource1)   { stub(resource=Object.new).database_id { db1_id }.subject }
        let(:resource2)   { stub(resource=Object.new).database_id { db1_id }.subject }
        let(:container1)  { stub(container=Object.new).resource { resource1 }.subject }
        let(:container2)  { stub(container=Object.new).resource { resource2 }.subject }

        it "registers the database containers" do
          mock(container1).resource { resource1 }
          mock(container2).resource { resource2 }
          subject.register_database(db1)
          subject.register_containers(db1)
          subject.find_container_by_resource(resource1).must_equal container1
          subject.find_container_by_resource(resource2).must_equal container2
        end

        it "removes container registration when the database is removed" do
          subject.register_database(db1)
          subject.register_containers(db1)
          subject.remove_database(db1_id)
          subject.find_container_by_resource(resource1).must_equal nil
          subject.find_container_by_resource(resource2).must_equal nil
        end
      end
    end
  end
end
