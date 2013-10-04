require 'bundler/setup'
require 'minitest/autorun'
require 'ostruct'

require 'rod/database/metadata'
require 'rod/database/resource_metadata'
require 'rod/exception'
require_relative '../spec_helper'

CREATION_TIME = Time.new(2012,1,1,10,20)
UPDATE_TIME = CREATION_TIME + 10
VERSION = "0.7.2"

module Rod
  module Database
    describe Metadata do
      subject                 { Metadata.new(database,metadata_factory,creation_clock) }
      let(:database)          { stub(db = Object.new).path {db_path}
                                stub(db).classes { resources }
                                stub(db).special_classes { [] }
                                db
                              }
      let(:db_path)           { "some_path/" }
      let(:dep_tree_factory)  { stub(dep_tree_factory = Object.new).new {dep_tree}
                                dep_tree_factory
                              }
      let(:dep_tree)          { Object.new }
      let(:creation_clock)    { stub(clock = Object.new).now {creation_time}
                                clock
                              }
      let(:creation_time)     { CREATION_TIME }
      let(:resources )        { [resource1] }
      let(:resource1)         { stub(resource = Object.new).name { resource1_name }
                                resource
                              }
      let(:resource1_name)    { "Klass1" }
      let(:resource_metadata1){ data=OpenStruct.new
                                data.name = resource1.name
                                stub(data).parent { Object }
                                stub(data).add_prefix {|prefix| data.name = prefix + data.name }
                                stub(data).to_hash { resource1_as_hash }
                                data
                              }
      let(:resource1_as_hash) { stub! }
      let(:metadata_factory)  { stub(factory = Object.new).build(resource1,database) { resource_metadata1 }
                                stub(factory).new(nil,database,anything) { resource_metadata1 }
                                factory
                              }

      it "returns its version" do
        subject.version.wont_be :nil?
      end

      it "returns version in the proper format" do
        (subject.version =~ /\A\d+\.\d+\.\d+\Z/).wont_be :nil?
      end

      it "allows to set the its version" do
        subject.version = "1.2.3"
        subject.version.must_equal "1.2.3"
      end

      it "returns the database it is connected with" do
        subject.database.must_equal database
      end

      it "allows to set its database" do
        alternative_db = Object.new
        subject.database = alternative_db
        subject.database.must_equal alternative_db
      end

      it "assigns the new database to resource meta-data" do
        alternative_db = Object.new
        stub(alternative_db).classes { [resource1] }
        stub(alternative_db).special_classes { [] }
        subject.database = alternative_db
        subject.resources.size.must_equal 1
        subject.resources.each{|name,data| data.database.must_equal alternative_db}
      end

      it "converts hash to itself" do
        hash = {
          "Rod" => {
            :version => VERSION,
            :created_at => CREATION_TIME,
            :updated_at => UPDATE_TIME
          },
          resource1_name => resource1_as_hash
        }
        metadata = Metadata.new(database,metadata_factory,creation_clock,hash)
        metadata.created_at.must_equal CREATION_TIME
        metadata.updated_at.must_equal UPDATE_TIME
        metadata.version.must_equal VERSION
        metadata.resources.size.must_equal 1
      end

      it "converts itself to a hash" do
        hash = subject.to_hash
        hash[Metadata::ROD_KEY][:created_at].must_equal CREATION_TIME
        hash[Metadata::ROD_KEY][:updated_at].must_equal CREATION_TIME
        hash[Metadata::ROD_KEY][:version].must_equal VERSION
        hash[resource1_name].must_equal resource1_as_hash
      end

      it "returns proper read/write path" do
        subject.path.must_equal "#{db_path}#{Metadata::METADATA_FILE}"
      end

      it "returns the dependency tree of the resources" do
        subject.dependency_tree(dep_tree_factory).must_equal dep_tree
      end

      it "is valid if the library and the database have the same version" do
        subject.version = "0.1.0"
        subject.valid?("0.1.0").must_equal true
      end

      it "is valid if the library version has the same minor number and higher patch-level number and the minor number is even" do
        subject.version = "0.2.0"
        subject.valid?("0.2.1").must_equal true
      end

      it "is not valid if the library version has the same minor number and higher patch-level number and the minor number is odd" do
        subject.version = "0.1.0"
        subject.valid?("0.1.1").must_equal false
      end

      it "is not valid if the library has older number than the database" do
        subject.version = "0.1.1"
        subject.valid?("0.1.0").must_equal false
        subject.version = "0.2.1"
        subject.valid?("0.2.0").must_equal false
      end

      it "has the creation time set to the time the metadata was created" do
        subject.created_at.must_equal creation_time
      end

      it "has the update time set to the time the metadata was updated" do
        update_time = creation_time + 10
        stub(update_clock = Object.new).now {update_time}
        subject.clock = update_clock
        descriptor = subject.to_hash
        descriptor[Metadata::ROD_KEY][:updated_at].must_equal update_time
        descriptor[Metadata::ROD_KEY][:created_at].must_equal creation_time
        descriptor[Metadata::ROD_KEY][:updated_at].wont_equal creation_time

        # "wait" 10 seconds
        update_time = update_time + 10
        descriptor = subject.to_hash
        descriptor[Metadata::ROD_KEY][:updated_at].must_equal update_time
      end

      it "returns the resource meta-data that are connected with the described DB" do
        subject.resources[resource1.name].must_equal resource_metadata1
      end

      it "allows to add a prefix to the names of the classes that are represented" do
        prefix = "Generated::"
        subject.add_prefix(prefix)
        name,metadata = subject.resources.first
        name.must_equal prefix + resource1.name
        metadata.name.must_equal prefix + resource1.name
      end

      describe "resource configuration" do
        it "raises exception if there is a resource missing in runtime" do
          metadata = subject # called, to create the subject with prvious DB config.
          stub(database).classes { [] }
          stub(database).configure_count { nil }
          stub(resource_metadata1).check_compatibility { true }
          (->{metadata.configure_resources}).must_raise DatabaseError
        end

        it "raises exception if resource configuration is incompatible" do
          metadata = subject # called, to create the subject with prvious DB config.
          stub(database).configure_count { nil }
          stub(resource_metadata1).check_compatibility { raise IncompatibleClass.new("") }
          (->{metadata.configure_resources}).must_raise IncompatibleClass
        end

        it "does not raise incompatibility exception if comp. check is not performetd" do
          metadata = subject # called, to create the subject with prvious DB config.
          stub(database).configure_count { nil }
          stub(resource_metadata1).check_compatibility { raise IncompatibleClass.new("") }
          (->{metadata.configure_resources(true)}).must_be_silent
        end

        it "configures count for the resources" do
          metadata = subject # called, to create the subject with prvious DB config.
          def database.configure_count(resource,count)
            @count ||= {}
            @count[resource] = count
          end
          def database.count(resource)
            @count[resource]
          end
          stub(resource_metadata1).check_compatibility { true }
          stub(resource_metadata1).count { 5 }
          metadata.configure_resources
          database.count(resource1).must_equal 5
        end
      end

      describe "resource generation" do
        it "generates the resources accroding to the data it contains" do
          skip
        end
      end
    end
  end
end
