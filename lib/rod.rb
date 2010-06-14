require 'inline'
require 'english/inflect'
require 'facets'
require 'weak_hash'

files = Dir.glob(File.join(File.dirname(__FILE__), 'rod/**.rb'))
files.each{ |f| require f }
