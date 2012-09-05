require 'minitest/autorun'
require 'ostruct'
require_relative '../../lib/rod/database/metadata'
require_relative '../../lib/rod/database/resource_metadata'
require_relative '../spec_helper'

CREATION_TIME = Time.new(2012,1,1,10,20)
UPDATE_TIME = CREATION_TIME + 10
VERSION = "0.7.2"
INPUT =<<-END
--- !<database>
Rod:
  :version: #{VERSION}
  :created_at: #{CREATION_TIME.to_s}
  :updated_at: #{UPDATE_TIME.to_s}
RodTest::HisStruct: !<resource>
  :name_hash: 994169277
  :superclass: RodTest::Model
  :count: 500
  :field:
    :some_field:
      :type: :integer
END

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
      let(:resource1)         { stub(resource = Object.new).name { "Klass1" }
                                resource
                              }
      let(:resource_metadata1){ data=OpenStruct.new
                                data.name = resource1.name
                                stub(data).parent { Object }
                                stub(data).add_prefix {|prefix| data.name = prefix + data.name }
                                data
                              }
      let(:metadata_factory)  { stub(factory = Object.new).build(resource1,database) { resource_metadata1 }
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

      it "loads itself from a YAML file" do
        input_stream = StringIO.new(INPUT)
        def input_stream.open(path)
          yield self
        end
        metadata = Metadata.load(database,metadata_factory,input_stream)
        metadata.created_at.must_equal CREATION_TIME
        metadata.updated_at.must_equal UPDATE_TIME
        metadata.version.must_equal VERSION
        metadata.resources.size.must_equal 1
      end

      it "stors itself to an output stream" do
        output_stream = StringIO.new("")
        def output_stream.open(path,mode)
          yield self
        end
        subject.store(output_stream)
        metadata = YAML::load(output_stream.string)
        metadata.created_at.must_equal CREATION_TIME
        metadata.updated_at.must_equal CREATION_TIME
        metadata.version.must_equal VERSION
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
        subject.store(StringIO)
        subject.updated_at.must_equal update_time
        subject.created_at.must_equal creation_time
        subject.updated_at.wont_equal creation_time

        # "wait" 10 seconds
        update_time = update_time + 10
        subject.store(StringIO)
        subject.updated_at.must_equal update_time
      end

      it "configures the resources accroding to the data it contains" do
        skip
      end

      it "generates the resources accroding to the data it contains" do
        skip
      end

      it "returns the resource meta-data that are connected with the described DB" do
        skip
      end

      it "allows to add a prefix to the names of the classes that are represented" do
        prefix = "Generated::"
        subject.add_prefix(prefix)
        name,metadata = subject.resources.first
        name.must_equal prefix + resource1.name
        metadata.name.must_equal prefix + resource1.name
      end

    end
  end
end
