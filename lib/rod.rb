require 'inline'
require 'english/inflect'
require 'weak_hash'
require 'active_model'

alias :oldrequire :require
def require(*args)
  oldrequire(*args)
end

files = Dir.glob(File.join(File.dirname(__FILE__), 'rod/**.rb'))
files.each{ |f| require f }
