require 'inline'
require 'english/inflect'
require 'weak_hash'
require 'active_model'
require 'active_support/dependencies'

# XXX This should be done in a different way, since a library should not
# impose on a user of another library specific way of using it.
# See #21
ActiveSupport::Dependencies.mechanism = :require

module Rod
  VERSION = "0.5.2"
end

files = Dir.glob(File.join(File.dirname(__FILE__), 'rod/**.rb'))
files.each{ |f| require f }
