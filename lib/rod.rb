require 'inline'
require 'english/inflect'
require 'active_model/deprecated_error_methods'
require 'active_model/validator'
require 'active_model/naming'
require 'active_model/translation'
require 'active_model/validations'
require 'active_model/dirty'
require 'active_support/dependencies'

# XXX This should be done in a different way, since a library should not
# impose on a user of another library specific way of using it.
# See #21
ActiveSupport::Dependencies.mechanism = :require

require 'rod/abstract_database'
require 'rod/abstract_model'
require 'rod/constants'
require 'rod/database'
require 'rod/exception'
require 'rod/join_element'
require 'rod/cache'
require 'rod/collection_proxy'
require 'rod/model'
require 'rod/reference_updater'
require 'rod/string_element'
require 'rod/string_ex'
require 'rod/index/base'
require 'rod/index/flat_index'
require 'rod/index/hash_index'
require 'rod/index/segmented_index'
