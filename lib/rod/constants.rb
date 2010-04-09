module Rod
  TYPE_MAPPING = { 
    :string => 'char *', 
    :integer => 'long', 
    :float => 'double',
    :ulong => 'unsigned long'
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

  EXCEPTION_CLASS = "rb_const_get(rb_cObject, rb_intern(\"Exception\"))"
end
