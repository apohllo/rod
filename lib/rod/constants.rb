module Rod
  VERSION = "0.5.3"

  # The name of file containing the data base.
  DATABASE_FILE = "database.dat"

  # Invalid names of fields.
  INVALID_NAMES = {"rod_id" => true}

  # The exception raised by Database C implementation.
  EXCEPTION_CLASS = "rb_const_get(rb_cObject, rb_intern(\"Exception\"))"

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
    :ulong => 'INT2NUM'
  }

end
