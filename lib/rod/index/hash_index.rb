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

      # Initializes the index with +path+ and +class+.
      # Options are not (yet) used.
      def initialize(path,klass,options={})
        @path = path + ".db"
        @klass = klass
        _open(@path,:create => true)
        @index = {}
        @opened = true
      end

      # Stores the index on disk.
      def save
        return if @index.empty?
        index = {}
        self.each{|k,v| index[k] = v}
        _close()
        puts "Saving #{index.size}"
        _open(@path,:truncate => true)
        index.each do |key,collection|
          key = Marshal.dump(key)
          _put(key,collection.offset,collection.size)
        end
        @index.clear
        _close()
        @opened = false
      end

      # Clears the contents of the index.
      def destroy
        _close()
        _open(@path,:truncate => true)
        _close()
        @opened = false
      end

      # Simple iterator.
      def each
        if block_given?
          @index.each do |key,value|
            yield key,value
          end
          _open(@path,{}) unless opened?
          _each_key do |key|
            next if key.empty?
            key = Marshal.load(key)
            unless @index[key]
              yield key,self[key]
            end
          end
        else
          enum_for(:each)
        end
      end

      protected
      def opened?
        @opened
      end

      def get(key)
        return @index[key] if @index.has_key?(key)
        begin
          _open(@path,{}) unless opened?
          value = _get(Marshal.dump(key))
        rescue Rod::KeyMissing => ex
          value = nil
        end
        @index[key] = value
      end

      def set(key,value)
        @index[key] = value
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
        |void _convert_key(VALUE key, DBT *db_key_p){
        |  long int_key;
        |  double float_key;
        |  DBT db_key;
        |
        |  db_key = *db_key_p;
        |  memset(&db_key, 0, sizeof(DBT));
        |  db_key.data = RSTRING_PTR(key);
        |  db_key.size = RSTRING_LEN(key);
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
        |void _each_key(){
        |  VALUE handle;
        |  DB *db_pointer;
        |  DBC *cursor;
        |  DBT db_key, db_value;
        |  int return_value;
        |  rod_entry_struct *entry;
        |  VALUE key;
        |
        |  handle = rb_iv_get(self,"@handle");
        |  Data_Get_Struct(handle,DB,db_pointer);
        |  if(db_pointer != NULL){
        |    db_pointer->cursor(db_pointer,NULL,&cursor,0);
        |    memset(&db_key, 0, sizeof(DBT));
        |    memset(&db_value, 0, sizeof(DBT));
        |    db_key.flags = DB_DBT_MALLOC;
        |    while((return_value = cursor->get(cursor, &db_key, &db_value, DB_NEXT)) == 0){
        |      key = rb_str_new((char *)db_key.data,db_key.size);
        |      free(db_key.data);
        |      rb_yield(key);
        |    }
        |    if(return_value != DB_NOTFOUND){
        |      rb_raise(rodException(),"%s",db_strerror(return_value));
        |    }
        |    cursor->close(cursor);
        |  } else {
        |    rb_raise(rodException(),"DB handle is NULL\\n");
        |  }
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
        |    db_value.data = &entry;
        |    db_value.ulen = sizeof(rod_entry_struct);
        |    db_value.flags = DB_DBT_USERMEM;
        |
        |    memset(&db_key, 0, sizeof(DBT));
        |    db_key.data = RSTRING_PTR(key);
        |    db_key.size = RSTRING_LEN(key);
        |
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
        |  memset(&db_key, 0, sizeof(DBT));
        |  db_key.data = RSTRING_PTR(key);
        |  db_key.size = RSTRING_LEN(key);
        |  memset(&db_value, 0, sizeof(DBT));
        |  entry.offset = offset;
        |  entry.size = size;
        |  db_value.data = &entry;
        |  db_value.size = sizeof(rod_entry_struct);
        |  if(db_pointer != NULL){
        |    return_value = db_pointer->put(db_pointer, NULL, &db_key, &db_value, 0);
        |    if(return_value != 0){
        |      rb_raise(rodException(),"%s",db_strerror(return_value));
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
