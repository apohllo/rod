# encoding: utf-8
require 'rod/index/base'

module Rod
  module Index
    # This implementation of index is based on the
    # Berkeley DB Hash access method.
    class HashIndex < Base
      # Wrapper class for the database struct.
      class Handle
      end

      def initialize(path,options={})
        @path = path + ".db"
        _open(@path,:create => true)
        @index = {}
      end

      def save
        @index.each do |key,value|
          offset,size = value
          key = Marshal.dump(key)
          _put(key,offset,size)
        end
        _close()
      end

      def destroy
        _close()
        _open(@path,:truncate => true)
      end

      def [](key)
        return @index[key] if @index.has_key?(key)
        begin
          value = _get(Marshal.dump(key))
        rescue Rod::KeyMissing => ex
          value = nil
        end
        @index[key] = value
      end

      def []=(key,value)
        @index[key] = value
      end

      def each
        if block_given?
          @index.each do |key,value|
            yield key,value
          end
          _each do |key,value|
            key = Marshal.load(key)
            unless @index[key]
              yield key,value
            end
          end
        else
          enum_for(:each)
        end
      end

      def self.rod_exception
        str =<<-END
        |VALUE rodException(){
        |  VALUE klass = rb_const_get(rb_cObject, rb_intern("Rod"));
        |  klass = rb_const_get(klass, rb_intern("DatabaseError"));
        |  return klass;
        |}
        END
        str.margin
      end

      def self.entry_struct
        str =<<-END
        |typedef struct rod_entry {
        |  unsigned long offset;
        |  unsigned long size;
        |} rod_entry_struct;
        END
        str.margin
      end

      def self.convert_key
        str =<<-END
        |DBT _convert_key(VALUE key){
        |  long int_key;
        |  double float_key;
        |  DBT db_key;
        |
        |  memset(&db_key, 0, sizeof(DBT));
        |  if(rb_obj_is_kind_of(key,rb_cInteger)){
        |    int_key = NUM2LONG(key);
        |    db_key.data = &int_key;
        |    db_key.size = sizeof(long);
        |  } else if(rb_obj_is_kind_of(key,rb_cFloat)){
        |    float_key = NUM2DBL(key);
        |    db_key.data = &float_key;
        |    db_key.size = sizeof(double);
        |  } else {
        |    db_key.data = RSTRING_PTR(key);
        |    db_key.size = RSTRING_LEN(key);
        |  }
        |  // is it legal?
        |  return db_key;
        |}
        END
        str.margin
      end

      def self.key_missing_exception
        str =<<-END
        |VALUE keyMissingException(){
        |  VALUE klass = rb_const_get(rb_cObject, rb_intern("Rod"));
        |  klass = rb_const_get(klass, rb_intern("KeyMissing"));
        |  return klass;
        |}
        END
        str.margin
      end

      self.inline(:C) do |builder|
        builder.include '<db.h>'
        builder.include '<stdio.h>'
        builder.add_compile_flags '-ldb-4.8'
        builder.prefix(self.entry_struct)
        builder.prefix(self.rod_exception)
        builder.prefix(self.key_missing_exception)
        builder.prefix(self.convert_key)


        str =<<-END
        |void _open(const char * path, VALUE options){
        |  DB * db_pointer;
        |  u_int32_t flags;
        |  int return_value;
        |  VALUE handleClass;
        |  VALUE handle;
        |  VALUE mod;
        |  db_pointer = ALLOC(DB);
        |  return_value = db_create(&db_pointer,NULL,0);
        |  if(return_value != 0){
        |    rb_raise(rodException(),"%s",db_strerror(return_value));
        |  }
        |
        |  flags = 0;
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("create"))) == Qtrue){
        |    flags |= DB_CREATE;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("truncate"))) == Qtrue){
        |    flags |= DB_TRUNCATE;
        |  }
        |
        |  return_value = db_pointer->open(db_pointer,NULL,path,
        |    NULL,DB_HASH,flags,0);
        |  if(return_value != 0){
        |    rb_raise(rodException(),"%s",db_strerror(return_value));
        |  }
        |  mod = rb_const_get(rb_cObject, rb_intern("Rod"));
        |  mod = rb_const_get(mod, rb_intern("Index"));
        |  mod = rb_const_get(mod, rb_intern("HashIndex"));
        |  handleClass = rb_const_get(mod, rb_intern("Handle"));
        |  // TODO the handle memory should be made free
        |  handle = Data_Wrap_Struct(handleClass,0,0,db_pointer);
        |  rb_iv_set(self,"@handle",handle);
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |void _close(){
        |  VALUE handle;
        |  DB *db_pointer;
        |  handle = rb_iv_get(self,"@handle");
        |  Data_Get_Struct(handle,DB,db_pointer);
        |  if(db_pointer != NULL){
        |    db_pointer->close(db_pointer,0);
        |    rb_iv_set(self,"@handle",Qnil);
        |  } else {
        |    rb_raise(rodException(),"DB handle is NULL\\n");
        |  }
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |void _each(){
        |
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |VALUE _get(VALUE key){
        |  VALUE handle;
        |  DB *db_pointer;
        |  DBT db_key, db_value;
        |  rod_entry_struct entry;
        |  VALUE result;
        |  int return_value;
        |
        |  handle = rb_iv_get(self,"@handle");
        |  Data_Get_Struct(handle,DB,db_pointer);
        |  if(db_pointer != NULL){
        |    memset(&db_value, 0, sizeof(DBT));
        |    db_key = _convert_key(key);
        |    db_value.data = &entry;
        |    db_value.ulen = sizeof(rod_entry_struct);
        |    db_value.flags = DB_DBT_USERMEM;
        |    return_value = db_pointer->get(db_pointer, NULL, &db_key, &db_value, 0);
        |    if(return_value == DB_NOTFOUND){
        |      rb_raise(keyMissingException(),"%s",db_strerror(return_value));
        |    } else if(return_value != 0){
        |      rb_raise(rodException(),"%s",db_strerror(return_value));
        |    } else {
        |      result = rb_ary_new();
        |      rb_ary_push(result,ULONG2NUM(entry.offset));
        |      rb_ary_push(result,ULONG2NUM(entry.size));
        |      return result;
        |    }
        |  } else {
        |    rb_raise(rodException(),"DB handle is NULL\\n");
        |  }
        |  return Qnil;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |void _put(VALUE key,unsigned long offset,unsigned long size){
        |  VALUE handle;
        |  DB *db_pointer;
        |  DBT db_key, db_value;
        |  rod_entry_struct entry;
        |  int return_value;
        |
        |  handle = rb_iv_get(self,"@handle");
        |  Data_Get_Struct(handle,DB,db_pointer);
        |  memset(&db_value, 0, sizeof(DBT));
        |  entry.offset = offset;
        |  entry.size = size;
        |  db_key = _convert_key(key);
        |  db_value.data = &entry;
        |  db_value.size = sizeof(rod_entry_struct);
        |  if(db_pointer != NULL){
        |    return_value = db_pointer->put(db_pointer, NULL, &db_key, &db_value, 0);
        |    if(return_value != 0){
        |      rb_raise(keyMissingException(),"%s",db_strerror(return_value));
        |    }
        |  } else {
        |    rb_raise(rodException(),"DB handle is NULL\\n");
        |  }
        |}
        END
        builder.c(str.margin)
      end
    end
  end
end
