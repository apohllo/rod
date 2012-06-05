module Rod
  module Berkeley
    class Database
      # The environment of the database.
      attr_reader :environment

      # The path of the database.
      attr_reader :path

      # Initializes the database as working within the given
      # +environment+.
      def initialize(environment)
        # TODO allow standalone databases
        @environment = environment
        @opened = false
      end

      # Opens the Berkeley DB database at given +path+ with given +access_method+.
      #
      # The followin access methods are supported (see the Berkeley DB documentation
      # for full description of the access methods):
      # * +:btree+ - sorted, balanced tree
      # * +:hash+ - hash table
      # * +:queue+ - queue
      # * +:recno+ - recno
      # * +:heap+ - heap NOT SUPPORTED!
      #
      # The following options are supported (see the Berkeley DB documentation
      # for full description of the flags):
      # * +:auto_commit: - automaticaly commit each database change,
      #   BDB: +DB_AUTO_COMMIT+
      # * +:create: - create the database if it doesn't exist, BDB: +DB_CREATE+
      # * +:create_exclusive: - check if the database exists when creating it,
      #   if it exists - raise an error, BDB: +DB_EXCL+
      # * +:multiversion: - use multiversion concurrency control to perform transaction
      #   snapshot isolation, BDB: +DB_MULTIVERSION+
      # * +:no_mmap: - don't map this database to the process memory, BDB: +DB_NOMMAP+
      # * +:readonly: - work in readonly mode - all database changes will fail,
      #   BDB: +DB_RDONLY+
      # * +:read_uncommitted: - perform transaction degree 1 isolation,
      #   BDB: +DB_READ_UNCOMMITTED+
      # * +:threads+ allow multiple threads within one process to access the databases,
      #   BDB: +DB_THREAD+
      # * +:truncate: - empty the database on creation, BDB: +DB_TRUNCATE+
      def open(path,access_method,options={})
        # TODO check for validity of the method
        # TODO check for validity of options
        # TODO check for conflicting options
        raise DatabaseError.new("The database is already opened at #{@path}.") if opened?
        _open(path,access_method,options)
        @path = path
        @opened = true
      end

      # Closes the database.
      def close
        _close
        @opened = false
      end

      # Returns true if the database is opened.
      def opened?
        @opened
      end

      # Put the +value+ to the database at the specified +key+.
      # The operation might be protected by the +transaction+.
      # Both the value and the key are marshaled before being stored.
      def put(key,value,transaction=nil)
        marshaled_key = Marshal.dump(key)
        marshaled_value = Marshal.dump(value)
        _put_strings(marshaled_key,marshaled_value,transaction)
      end


      # Return the value of the database for the specified +key+.
      # The operation might be protected by the +transaction+.
      # The key is marshaled before being stored looked up in the database.
      def get(key,transaction=nil)
        marshaled_key = Marshal.dump(key)
        Marshal.load(_get_strings(marshaled_key,transaction))
      end

      class << self
        # The C definition of the KeyMissing exception.
        def key_missing_exception
          str =<<-END
          |VALUE keyMissingException(){
          |  VALUE klass;
          |
          |  klass = rb_const_get(rb_cObject, rb_intern("Rod"));
          |  klass = rb_const_get(klass, rb_intern("KeyMissing"));
          |  return klass;
          |}
          END
          str.margin
        end
      end

      inline(:C) do |builder|
        Rod::Berkeley::Environment.init_builder(builder)
        builder.prefix(Rod::Berkeley::Environment.database_error)
        builder.prefix(self.key_missing_exception)

        str =<<-END
        |/*
        |* Closes the database causing the resources to be freed.
        |*/
        |void db_free(DB * db_pointer){
        |  int return_value;
        |
        |  if(db_pointer != NULL){
        |    return_value = db_pointer->close(db_pointer,0);
        |    if(return_value != 0){
        |      rb_raise(databaseError(),"%s",db_strerror(return_value));
        |    }
        |  }
        |}
        END
        builder.prefix(str.margin)

        str =<<-END
        |/*
        |* Replaces default allocate with function returning wrapper for the
        |* database struct.
        |*/
        |VALUE allocate(){
        |  // db_mark == NULL - no internal elements have to be marked
        |  // struct == NULL - there is no struct to wrap at the moment
        |  return Data_Wrap_Struct(self,NULL,db_free,NULL);
        |}
        END
        builder.c_singleton(str.margin)

        str =<<-END
        |/*
        |* Opens the database on the +path+ given with the access +method+ specified.
        |* See +open+ for a list of options.
        |*/
        |void _open(const char * path, VALUE method, VALUE options){
        |  DB_ENV * env_pointer;
        |  DB * db_pointer;
        |  DBTYPE access_method;
        |  u_int32_t flags;
        |  int return_value;
        |  VALUE environment;
        |
        |  environment = rb_iv_get(self,"@environment");
        |  if(NIL_P(environment)){
        |    rb_raise(databaseError(),"The environment of the database at %s is nil!",path);
        |  }
        |  Data_Get_Struct(environment,DB_ENV,env_pointer);
        |  if(env_pointer == NULL){
        |    rb_raise(databaseError(),"The environment of the database at %s is NULL!",path);
        |  }
        |  // the flags could be DB_XA_CREATE, but we don't support it so far.
        |  return_value = db_create(&db_pointer, env_pointer, 0);
        |  if(return_value != 0){
        |    rb_raise(databaseError(),"%s",db_strerror(return_value));
        |  }
        |
        |  flags = 0;
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("auto_commit"))) == Qtrue){
        |    flags |= DB_AUTO_COMMIT;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("create"))) == Qtrue){
        |    flags |= DB_CREATE;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("create_exclusive"))) == Qtrue){
        |    flags |= DB_EXCL;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("multiversion"))) == Qtrue){
        |    flags |= DB_MULTIVERSION;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("no_mmap"))) == Qtrue){
        |    flags |= DB_NOMMAP;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("readonly"))) == Qtrue){
        |    flags |= DB_RDONLY;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("read_uncommitted"))) == Qtrue){
        |    flags |= DB_READ_UNCOMMITTED;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("threads"))) == Qtrue){
        |    flags |= DB_THREAD;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("truncate"))) == Qtrue){
        |    flags |= DB_TRUNCATE;
        |  }
        |
        |  // access method
        |  if(ID2SYM(rb_intern("btree")) == method){
        |    method = DB_BTREE;
        |  } else if(ID2SYM(rb_intern("hash")) == method){
        |    method = DB_BTREE;
        |  } else if(ID2SYM(rb_intern("heap")) == method){
        |  // DB_HEAP no supported in the library
        |  //  method = DB_HEAP;
        |  } else if(ID2SYM(rb_intern("queue")) == method){
        |    method = DB_QUEUE;
        |  } else if(ID2SYM(rb_intern("recno")) == method){
        |    method = DB_RECNO;
        |  } else {
        |    // only for existing databases
        |    method = DB_UNKNOWN;
        |  }
        |  // 1 NULL - transaction pointer
        |  // 2 NULL - logical database name (for many dbs in one file)
        |  // 0 - default file access mode
        |  return_value = db_pointer->open(db_pointer,NULL,path,NULL,method,flags,0);
        |  if(return_value != 0){
        |    rb_raise(databaseError(),"%s",db_strerror(return_value));
        |  }
        |  DATA_PTR(self) = db_pointer;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |/*
        |* Closes the database if it is opened.
        |*/
        |void _close(){
        |  DB * db_pointer;
        |  int return_value;
        |
        |  Data_Get_Struct(self,DB,db_pointer);
        |  db_free(db_pointer);
        |  DATA_PTR(self) = NULL;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |void _put(VALUE self,void * key,unsigned int key_size, void * value,
        |  unsigned int value_size, VALUE transaction){
        |  DB *db_pointer;
        |  DB_TXN *txn_pointer;
        |  DBT db_key, db_value;
        |  int return_value;
        |
        |  Data_Get_Struct(self,DB,db_pointer);
        |
        |  memset(&db_key, 0, sizeof(DBT));
        |  db_key.data = key;
        |  db_key.size = key_size;
        |
        |  memset(&db_value, 0, sizeof(DBT));
        |  db_value.data = value;
        |  db_value.size = value_size;
        |
        |  if(db_pointer == NULL){
        |    rb_raise(databaseError(),"The handle for the database is NULL!");
        |  }
        |  // TODO options
        |  if(NIL_P(transaction)){
        |    return_value = db_pointer->put(db_pointer, NULL, &db_key, &db_value, 0);
        |  } else {
        |    Data_Get_Struct(transaction,DB_TXN,txn_pointer);
        |    return_value = db_pointer->put(db_pointer, txn_pointer, &db_key, &db_value, 0);
        |  }
        |  if(return_value != 0){
        |    rb_raise(databaseError(),"%s",db_strerror(return_value));
        |  }
        |}
        END
        builder.prefix(str.margin)

        str =<<-END
        |/*
        |* Put the string key-value pair to the database.
        |*/
        |void _put_strings(VALUE key, VALUE value, VALUE transaction){
        |  _put(self,RSTRING_PTR(key),RSTRING_LEN(key),RSTRING_PTR(value),
        |    RSTRING_LEN(value),transaction);
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |unsigned int _get(VALUE self, void * key, unsigned int key_size,
        |  void * value, unsigned int value_size, VALUE transaction){
        |  DB *db_pointer;
        |  DB_TXN *txn_pointer;
        |  DBT db_key, db_value;
        |  int return_value;
        |
        |  Data_Get_Struct(self,DB,db_pointer);
        |
        |  if(db_pointer == NULL){
        |    rb_raise(databaseError(),"The handle for the database is NULL!");
        |  }
        |
        |  memset(&db_value, 0, sizeof(DBT));
        |  db_value.data = value;
        |  db_value.ulen = value_size;
        |  db_value.flags = DB_DBT_USERMEM;
        |
        |  memset(&db_key, 0, sizeof(DBT));
        |  db_key.data = key;
        |  db_key.size = key_size;
        |
        |  if(NIL_P(transaction)){
        |    return_value = db_pointer->get(db_pointer, NULL, &db_key, &db_value, 0);
        |  } else {
        |    Data_Get_Struct(transaction,DB_TXN,txn_pointer);
        |    return_value = db_pointer->get(db_pointer, txn_pointer, &db_key, &db_value, 0);
        |  }
        |  if(return_value == DB_NOTFOUND){
        |    rb_raise(keyMissingException(),"%s",db_strerror(return_value));
        |  } else if(return_value != 0){
        |    rb_raise(databaseError(),"%s",db_strerror(return_value));
        |  }
        |  return db_value.size;
        |}
        END
        builder.prefix(str.margin)

        str =<<-END
        |/*
        |* Get the value for given +key+. The key and the value
        |* are supposed to be strings. The result size is limited to 1024 bytes.
        |*/
        |VALUE _get_strings(VALUE key, VALUE transaction){
        |  char buffer[1024];
        |  VALUE result;
        |  unsigned int size;
        |
        |  size = _get(self,RSTRING_PTR(key),RSTRING_LEN(key),buffer,1024,transaction);
        |  return rb_str_new(buffer,size);
        |}
        END
        builder.c(str.margin)
      end
    end
  end
end
