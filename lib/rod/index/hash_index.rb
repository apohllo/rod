# encoding: utf-8
require 'rod/index/base'

module Rod
  module Index
    # This implementation of index is based on the
    # Berkeley DB Hash access method.
    class HashIndex < Base
      # Wrapper class for the database C struct.
      class Handle
      end

      # The class given index is associated with.
      attr_reader :klass

      # Initializes the index with +path+ and +class+.
      # Options are not (yet) used.
      def initialize(path,klass,options={})
        @path = path + ".db"
        @klass = klass
        open(@path,:create => true)
      end

      # Stores the index on disk.
      def save
        raise RodException.new("The index #{self} is not opened!") unless opened?
        close
      end

      # Clears the contents of the index.
      def destroy
        close if opened?
        open(@path,:truncate => true)
      end

      # Iterates over the keys and corresponding
      # values present in the index.
      def each
        if block_given?
          open(@path) unless opened?
          _each_key do |key|
            next if key.empty?
            key = Marshal.load(key)
            yield key,self[key]
          end
        else
          enum_for(:each)
        end
      end

      # Copies the index from the given +index+.
      # The index have to cleared before being copied.
      def copy(index)
        close if opened?
        open(@path,:truncate => true)
        super(index)
      end

      # Delets given +value+ for the given +key+.
      # If the +value+ is nil, then the key is removed
      # with all the values.
      def delete(key,value=nil)
        _delete(key,value)
      end

      # Registers given +rod_id+ for the given +key+.
      def put(key,rod_id)
        _put(key,rod_id)
      end

      # Iterates over all values for a given +key+. Raises
      # KeyMissing if the key is not present.
      def each_for(key)
        _get(key) do |value|
          yield value
        end
      end

      # Returns the first value for a given +key+ or
      # raises keyMissing exception if it is not present.
      def get_first(key)
        _get_first(key)
      end


      protected
      # Returns an empty BDB based collection proxy.
      def empty_collection_proxy(key)
        key = key.encode("utf-8") if key.is_a?(String)
        key = Marshal.dump(key)
        Rod::Berkeley::CollectionProxy.new(self,key)
      end

      # Opens the index - initializes the index C structures
      # and the cache.
      # Options:
      # * +:truncate+ - clears the contents of the index
      # * +:create+ - creates the index if it doesn't exist
      def open(path,options={})
        raise RodException.new("The index #{@path} is already opened!") if opened?
        _open(path,options)
        @opened = true
      end

      # Closes the disk - frees the C structure and clears the cache.
      def close
        return unless opened?
        _close()
        @opened = false
      end

      # Checks if the index is opened.
      def opened?
        @opened
      end

      # Returns a value of the index for a given +key+.
      def get(key)
        # TODO # 208
        open(@path) unless opened?
        empty_collection_proxy(key)
      end

      # Sets the +proxy+ for the +key+ in the internal cache.
      def set(key,proxy)
        # do nothing - the value is set in proxy#<< method
      end

      # C definition of the RodException.
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

      # C definition of the index struct.
      def self.entry_struct
        str =<<-END
        |typedef struct rod_entry {
        |  unsigned long offset;
        |  unsigned long size;
        |} rod_entry_struct;
        END
        str.margin
      end

      # Converts the key to the C representation.
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

      # The C definition of the KeyMissing exception.
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

      # The cursor free method.
      def self.cursor_free
        str =<<-END
        |void cursor_free(DBC *cursor){
        |  int return_value;
        |  if(cursor != NULL){
        |    return_value = cursor->close(cursor);
        |    if(return_value != 0){
        |      rb_raise(rodException(),"%s",db_strerror(return_value));
        |    }
        |  }
        |}
        END
        str.margin
      end

      # The cursor closing method.
      def self.close_cursor
        str =<<-END
        |VALUE close_cursor(VALUE cursor_object){
        |  DBC *cursor;
        |  int return_value;
        |  Data_Get_Struct(cursor_object,DBC,cursor);
        |  if(cursor != NULL){
        |    return_value = cursor->close(cursor);
        |    DATA_PTR(cursor_object) = NULL;
        |    if(return_value != 0){
        |      rb_raise(rodException(),"%s",db_strerror(return_value));
        |    }
        |  }
        |  return Qnil;
        |}
        END
        str.margin
      end

      def self.iterate_over_values
        str =<<-END
        |VALUE iterate_over_values(VALUE arguments){
        |  DBT db_key, db_value;
        |  DBC *cursor;
        |  unsigned long rod_id, index;
        |  VALUE key, result, cursor_object;
        |  int return_value;
        |
        |  index = 0;
        |  key = rb_ary_shift(arguments);
        |  cursor_object = rb_ary_shift(arguments);
        |  Data_Get_Struct(cursor_object,DBC,cursor);
        |
        |  memset(&db_value, 0, sizeof(DBT));
        |  db_value.data = &rod_id;
        |  db_value.ulen = sizeof(unsigned long);
        |  db_value.flags = DB_DBT_USERMEM;
        |
        |  memset(&db_key, 0, sizeof(DBT));
        |  db_key.data = RSTRING_PTR(key);
        |  db_key.size = RSTRING_LEN(key);
        |
        |  return_value = cursor->get(cursor, &db_key, &db_value, DB_SET);
        |  if(return_value == DB_NOTFOUND){
        |    rb_raise(keyMissingException(),"%s",db_strerror(return_value));
        |  } else if(return_value != 0){
        |    rb_raise(rodException(),"%s",db_strerror(return_value));
        |  }
        |  while(return_value != DB_NOTFOUND){
        |    index++;
        |    rb_yield(ULONG2NUM(rod_id));
        |    return_value = cursor->get(cursor, &db_key, &db_value, DB_NEXT_DUP);
        |    if(return_value != 0 && return_value != DB_NOTFOUND){
        |      rb_raise(rodException(),"%s",db_strerror(return_value));
        |    }
        |  }
        |  return Qnil;
        |}
        END
        str.margin
      end

      def self.iterate_over_keys
        str =<<-END
        |VALUE iterate_over_keys(VALUE cursor_object){
        |  DBT db_key, db_value;
        |  DBC *cursor;
        |  int return_value;
        |  rod_entry_struct *entry;
        |  VALUE key;
        |
        |  Data_Get_Struct(cursor_object,DBC,cursor);
        |  memset(&db_key, 0, sizeof(DBT));
        |  memset(&db_value, 0, sizeof(DBT));
        |  db_key.flags = DB_DBT_MALLOC;
        |  while((return_value = cursor->get(cursor, &db_key, &db_value, DB_NEXT_NODUP)) == 0){
        |    key = rb_str_new((char *)db_key.data,db_key.size);
        |    free(db_key.data);
        |    rb_yield(key);
        |  }
        |  if(return_value != DB_NOTFOUND){
        |    rb_raise(rodException(),"%s",db_strerror(return_value));
        |  }
        |  return Qnil;
        |}
        END
        str.margin
      end

      # You can set arbitrary ROD hash index compile flags via
      # ROD_HASH_COMPILE_FLAGS env. variable.
      def self.rod_compile_flags
        ENV['ROD_HASH_COMPILE_FLAGS'] || '-ldb'
      end

      self.inline(:C) do |builder|
        builder.include '<db.h>'
        builder.include '<stdio.h>'
        builder.add_compile_flags self.rod_compile_flags
        builder.prefix(self.entry_struct)
        builder.prefix(self.rod_exception)
        builder.prefix(self.key_missing_exception)
        builder.prefix(self.convert_key)
        builder.prefix(self.cursor_free)
        builder.prefix(self.close_cursor)
        builder.prefix(self.iterate_over_values)
        builder.prefix(self.iterate_over_keys)


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
        |  return_value = db_pointer->set_flags(db_pointer,DB_DUPSORT);
        |  if(return_value != 0){
        |    db_pointer->close(db_pointer,0);
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
        |  db_pointer->set_cachesize(db_pointer,0,5 * 1024 * 1024,0);
        |  return_value = db_pointer->open(db_pointer,NULL,path,
        |    NULL,DB_HASH,flags,0);
        |  if(return_value != 0){
        |    db_pointer->close(db_pointer,0);
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
        |// Iterate over all keys in the database.
        |// The value returned is the index itself.
        |VALUE _each_key(){
        |  VALUE handle;
        |  DB *db_pointer;
        |  DBC *cursor;
        |  VALUE key, cursor_object;
        |
        |  handle = rb_iv_get(self,"@handle");
        |  Data_Get_Struct(handle,DB,db_pointer);
        |  if(db_pointer != NULL){
        |    db_pointer->cursor(db_pointer,NULL,&cursor,0);
        |    cursor_object = Data_Wrap_Struct(rb_cObject,NULL,cursor_free,cursor);
        |    rb_ensure(iterate_over_keys,cursor_object,close_cursor,cursor_object);
        |  } else {
        |    rb_raise(rodException(),"DB handle is NULL\\n");
        |  }
        |  return self;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |// Iterate over values for a given key.
        |// A KeyMissing exception is raised if the key is missing.
        |// The value returned is the index itself.
        |VALUE _get(VALUE key){
        |  VALUE handle;
        |  DB *db_pointer;
        |  DBC *cursor;
        |  VALUE cursor_object, iterate_arguments;
        |
        |  handle = rb_iv_get(self,"@handle");
        |  Data_Get_Struct(handle,DB,db_pointer);
        |  if(db_pointer != NULL){
        |    db_pointer->cursor(db_pointer,NULL,&cursor,0);
        |    cursor_object = Data_Wrap_Struct(rb_cObject,NULL,cursor_free,cursor);
        |    iterate_arguments = rb_ary_new();
        |    rb_ary_push(iterate_arguments,key);
        |    rb_ary_push(iterate_arguments,cursor_object);
        |    rb_ensure(iterate_over_values,iterate_arguments,close_cursor,cursor_object);
        |  } else {
        |    rb_raise(rodException(),"DB handle is NULL\\n");
        |  }
        |  return self;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |// Returns the first value for a given +key+ or raises
        |// KeyMissing if the key is not present.
        |VALUE _get_first(VALUE key){
        |  VALUE handle;
        |  DB *db_pointer;
        |  DBT db_key, db_value;
        |  unsigned long rod_id;
        |  VALUE result;
        |  int return_value;
        |
        |  handle = rb_iv_get(self,"@handle");
        |  Data_Get_Struct(handle,DB,db_pointer);
        |  if(db_pointer != NULL){
        |    memset(&db_value, 0, sizeof(DBT));
        |    db_value.data = &rod_id;
        |    db_value.ulen = sizeof(unsigned long);
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
        |    }
        |    return ULONG2NUM(rod_id);
        |  } else {
        |    rb_raise(rodException(),"DB handle is NULL\\n");
        |  }
        |  // This should never be reached.
        |  rb_raise(rodException(),"Invalid _get_first implementation!\\n");
        |  return Qnil;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |void _put(VALUE key,unsigned long rod_id){
        |  VALUE handle;
        |  DB *db_pointer;
        |  DBT db_key, db_value;
        |  int return_value;
        |
        |  handle = rb_iv_get(self,"@handle");
        |  Data_Get_Struct(handle,DB,db_pointer);
        |  memset(&db_key, 0, sizeof(DBT));
        |  db_key.data = RSTRING_PTR(key);
        |  db_key.size = RSTRING_LEN(key);
        |  memset(&db_value, 0, sizeof(DBT));
        |  db_value.data = &rod_id;
        |  db_value.size = sizeof(unsigned long);
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

        str =<<-END
        |void _delete(VALUE key,VALUE value){
        |  VALUE handle;
        |  DB *db_pointer;
        |  DBT db_key, db_value;
        |  DBC *cursor;
        |  int return_value;
        |  unsigned long rod_id = 0;
        |
        |  handle = rb_iv_get(self,"@handle");
        |  Data_Get_Struct(handle,DB,db_pointer);
        |  memset(&db_key, 0, sizeof(DBT));
        |  db_key.data = RSTRING_PTR(key);
        |  db_key.size = RSTRING_LEN(key);
        |  memset(&db_value, 0, sizeof(DBT));
        |
        |  if(db_pointer != NULL){
        |    if(value == Qnil){
        |      return_value = db_pointer->del(db_pointer, NULL, &db_key, 0);
        |      if(return_value == DB_NOTFOUND){
        |        rb_raise(keyMissingException(),"%s",db_strerror(return_value));
        |      } else if(return_value != 0){
        |        rb_raise(rodException(),"%s",db_strerror(return_value));
        |      }
        |    } else {
        |      rod_id = NUM2ULONG(value);
        |      memset(&db_value, 0, sizeof(DBT));
        |      db_value.data = &rod_id;
        |      db_value.size = sizeof(unsigned long);
        |      db_pointer->cursor(db_pointer,NULL,&cursor,0);
        |      return_value = cursor->get(cursor,&db_key,&db_value,DB_GET_BOTH);
        |      if(return_value == DB_NOTFOUND){
        |        cursor->close(cursor);
        |        rb_raise(keyMissingException(),"%s",db_strerror(return_value));
        |      } else if(return_value != 0){
        |        cursor->close(cursor);
        |        rb_raise(rodException(),"%s",db_strerror(return_value));
        |      }
        |      return_value = cursor->del(cursor,0);
        |      cursor->close(cursor);
        |      if(return_value != 0){
        |        rb_raise(rodException(),"%s",db_strerror(return_value));
        |      }
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
