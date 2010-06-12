require 'inline'
require 'english/inflect'
require 'weak_hash'
require 'active_model'

files = Dir.glob(File.join(File.dirname(__FILE__), 'rod/**.rb'))
files.each{ |f| require f }
