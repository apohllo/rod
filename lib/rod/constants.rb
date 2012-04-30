module Rod
  VERSION = "0.7.0"

  # The name of file containing the data base.
  DATABASE_FILE = "database.yml"

  # Invalid names of fields.
  INVALID_NAMES = {"rod_id" => true}

  TYPE_MAPPING = {
    :string => 'char *',
    :integer => 'long',
    :float => 'double',
    :ulong => 'unsigned long',
    :object => 'char *'
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

  BIGENDIAN_READER = {
    'long' => 'bswap_64(*((long *)result))',
    'double' => 'bswap_64(*((unsigned long *)result))',
    'unsigned long' => 'bswap_64(*((unsigned long *)result))'
  }

  INLINE_PATTERN_RE = /\h+\.\w+$/

  LEGACY_DATA_SUFFIX = ".old"
  NEW_DATA_SUFFIX = ".new"
  LEGACY_MODULE = "Legacy"
  LEGACY_RE = /^#{LEGACY_MODULE}::/
  BACKUP_PREFIX = "backup/"

end
