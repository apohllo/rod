module Rod
  VERSION = "0.7.9"

  # Invalid names of fields.
  INVALID_NAMES = {"rod_id" => true}

  TYPE_MAPPING = {
    :string => 'char *',
    :integer => 'long',
    :float => 'double',
    :ulong => 'unsigned long',
    :object => 'char *',
    :json => 'char *'
  }

  RUBY_TO_C_MAPPING = {
    :string => 'StringValuePtr',
    :integer => 'NUM2LONG',
    :float => 'NUM2DBL',
    :ulong => 'NUM2ULONG'
  }

  C_TO_RUBY_MAPPING = {
    :string => 'rb_str_new2',
    :integer => 'INT2NUM',
    :float => 'rb_float_new',
    :ulong => 'ULONG2NUM'
  }

  INLINE_PATTERN_RE = /\h+\.\w+$/

  LEGACY_DATA_SUFFIX = ".old"
  NEW_DATA_SUFFIX = ".new"
  LEGACY_MODULE = "Legacy"
  LEGACY_RE = /^#{LEGACY_MODULE}::/
  BACKUP_PREFIX = "backup/"

end
