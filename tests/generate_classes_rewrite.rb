$:.unshift("lib")
require 'rod'
require File.join(".",File.dirname(__FILE__),"generate_classes_model")

Rod::Database::Base.development_mode = true
Database.instance.open_database("tmp/generate_classes",:readonly => false)
Database.instance.close_database
