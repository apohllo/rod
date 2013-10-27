#require 'inline'
#require 'english/inflect'
#require 'active_support/deprecation'
require 'active_support/inflector'
require 'active_model/validator'
require 'active_model/naming'
require 'active_model/translation'
require 'active_model/validations'
require 'active_model/dirty'
#require 'active_support/dependencies'
#require 'active_support/deprecation/behaviors'
#require 'active_support/deprecation/reporting'
#require 'active_support/core_ext/module/introspection'

require 'virtus'
#
## XXX This should be done in a different way, since a library should not
## impose on a user of another library specific way of using it.
## See #21
#ActiveSupport::Dependencies.mechanism = :require
#
require 'rod/metadata/metadata'
require 'rod/metadata/resource_metadata'

require 'rod/model/name_conversion'

#require 'rod/database/migration'
require 'rod/database/registry'
require 'rod/database/base'
#require 'rod/database/dependency_tree'
#
#require 'rod/constants'
require 'rod/exception'
#
#require 'rod/model/simple_resource'
require 'rod/model/resource_space'
require 'rod/model/resource'
#require 'rod/model/cache'
#require 'rod/model/generation'
#require 'rod/model/migration'
#require 'rod/model/join_element'
require 'rod/model/reference_updater'
#require 'rod/model/string_element'
#
#require 'rod/native/collection_proxy'
require 'rod/native/cache'
require 'rod/native/structure_store'
require 'rod/native/sequence_store'
require 'rod/native/container'
#
require 'rod/index/base'
require 'rod/index/flat_index'
require 'rod/index/hash_index'
require 'rod/index/field_updater'
#require 'rod/index/segmented_index'
#
require 'rod/property/base'
require 'rod/property/field'
require 'rod/property/singular_association'
require 'rod/property/plural_association'
require 'rod/property/class_methods'
require 'rod/property/virtus_adapter'

require 'rod/accessor/base'
require 'rod/accessor/float_accessor'
require 'rod/accessor/integer_accessor'
require 'rod/accessor/sequence_accessor'
require 'rod/accessor/json_accessor'
require 'rod/accessor/object_accessor'
require 'rod/accessor/string_accessor'
require 'rod/accessor/ulong_accessor'
require 'rod/accessor/singular_accessor'
require 'rod/accessor/plural_accessor'

require 'rod/berkeley/collection_proxy'
#require 'rod/berkeley/environment'
#require 'rod/berkeley/database'
#require 'rod/berkeley/transaction'
#require 'rod/berkeley/sequence'

module Rod
  def self.resource
    Model::Resource
  end
end
