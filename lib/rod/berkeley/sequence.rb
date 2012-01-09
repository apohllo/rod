module Rod
  module Berkeley
    class Sequence
      # The database of the sequence.
      attr_reader :database

      # Initializes the sequence as stored within the given
      # +database+.
      def initialize(database)
        @database = database
        @opened = false
      end

      # Opens the Berkeley DB sequence for the given +key+ with given +transaction+.
      #
      # The following options are supported (see the Berkeley DB documentation
      # for full description of the flags):
      # * +:cache_size - the number of cached values (default to 1)
      # * +:create - create the sequence if it doesn't exist, BDB: +DB_CREATE+
      # * +:create_exclusive - check if the sequence exists when creating it,
      #   if it exists - raise an error, BDB: +DB_EXCL+
      # * +:threads+ allow multiple threads within one process to use the sequence,
      #   BDB: +DB_THREAD+
      def open(key,transaction=nil,options={})
        if opened?
          raise DatabaseError.new("The seqence associated with the #{@database} is already opened.")
        end
        if String === key
          _open_string(key,transaction,options)
        else
          raise DatabaseError.new("#{key.class} type not supported for sequence keys.")
        end
      end

      # Closes the sequence.
      def close
        _close
        @opened = false
      end

      # Returns true if the database is opened.
      def opened?
        @opened
      end

      # Get the next value of the sequence.
      # The operation might be protected by the +transaction+ given.
      #
      # The following options are supported (see the Berkeley DB documentation
      # for full description of the flags):
      # * +:delta+ - the delta used to compute the next value of the sequence
      # * +:no_sync - do not flush synchronously to the log (ACI without D),
      #   BDB: +DB_TXN_NOSYNC+
      def next(transaction=nil,options={})
        delta = options.delete(:delta) || 1
        _next(transaction,delta,options)
      end

      inline(:C) do |builder|
        Rod::Berkeley::Environment.init_builder(builder)
        builder.prefix(Rod::Berkeley::Environment.database_error)

        str =<<-END
        |/*
        |* Closes the sequence causing the resources to be freed.
        |*/
        |void seq_free(DB_SEQUENCE * seq_pointer){
        |  int return_value;
        |  if(seq_pointer != NULL){
        |    return_value = seq_pointer->close(seq_pointer,0);
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
        |* sequence struct.
        |*/
        |VALUE allocate(){
        |  // db_mark == NULL - no internal elements have to be marked
        |  // struct == NULL - there is no struct to wrap at the moment
        |  return Data_Wrap_Struct(self,NULL,seq_free,NULL);
        |}
        END
        builder.c_singleton(str.margin)

        str =<<-END
        |/*
        |* Opens the sequence with +key+ in the associated database.
        |* The +key+ is the pointer to the key, and +key_size+ is its size.
        |* The operation might be protected by the +transaction+ given.
        |* See +open+ for a list of options.
        |*/
        |void _open_raw(VALUE self, void * key, unsigned int key_size, VALUE transaction, VALUE options){
        |  DB * db_pointer;
        |  DB_SEQUENCE * seq_pointer;
        |  DB_TXN *txn_pointer;
        |  int return_value;
        |  VALUE database;
        |  DBT db_key;
        |  u_int32_t flags;
        |  int32_t cache_size;
        |
        |
        |  database = rb_iv_get(self,"@database");
        |  if(NIL_P(database)){
        |    rb_raise(databaseError(),"The database of the sequence is nil!");
        |  }
        |  Data_Get_Struct(database,DB,db_pointer);
        |  if(db_pointer == NULL){
        |    rb_raise(databaseError(),"The database of the sequence is NULL!");
        |  }
        |  // Only 0 is a valid flag.
        |  return_value = db_sequence_create(&seq_pointer, db_pointer,0);
        |  if(return_value != 0){
        |    rb_raise(databaseError(),"%s",db_strerror(return_value));
        |  }
        |  // By default the sequence starts with 1.
        |  return_value = seq_pointer->initial_value(seq_pointer, 1);
        |
        |  memset(&db_key, 0, sizeof(DBT));
        |  db_key.data = key;
        |  db_key.size = key_size;
        |
        |  flags = 0;
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("create"))) == Qtrue){
        |    flags |= DB_CREATE;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("create_exclusive"))) == Qtrue){
        |    flags |= DB_EXCL;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("threads"))) == Qtrue){
        |    flags |= DB_THREAD;
        |  }
        |  cache_size = 1;
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("cache_size"))) != Qnil){
        |    cache_size = NUM2INT(rb_hash_aref(options,ID2SYM(rb_intern("cache_size"))));
        |  }
        |  seq_pointer->set_cachesize(seq_pointer,cache_size);
        |
        |  if(NIL_P(transaction)){
        |    return_value = seq_pointer->open(seq_pointer, NULL, &db_key, flags);
        |  } else {
        |    Data_Get_Struct(transaction,DB_TXN,txn_pointer);
        |    return_value = seq_pointer->open(seq_pointer, txn_pointer, &db_key, flags);
        |  }
        |  if(return_value != 0){
        |    rb_raise(databaseError(),"%s",db_strerror(return_value));
        |  }
        |  DATA_PTR(self) = seq_pointer;
        |}
        END
        builder.c_raw(str.margin)

        str =<<-END
        |/*
        |* Opens the sequence with a string key.
        |* See _open for the arguments.
        |*/
        |void _open_string(VALUE key, VALUE transaction, VALUE options){
        |  _open_raw(self,RSTRING_PTR(key),RSTRING_LEN(key),transaction,options);
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |/*
        |* Returns the next value of the seqence. The operation
        |* might be secured by the +transaction+. The sequence step
        |* is defined by +delta+.
        |* See +next+ for a list of options.
        |*/
        |unsigned long _next(VALUE transaction,int delta,VALUE options){
        |  DB_SEQUENCE *seq_pointer;
        |  DB_TXN *txn_pointer;
        |  int return_value;
        |  db_seq_t next_value;
        |  u_int32_t flags;
        |
        |  Data_Get_Struct(self,DB_SEQUENCE,seq_pointer);
        |  if(seq_pointer == NULL){
        |    rb_raise(databaseError(),"The handle for the sequence is NULL!");
        |  }
        |
        |  flags = 0;
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("no_sync"))) == Qtrue){
        |    flags |= DB_TXN_NOSYNC;
        |  }
        |  if(NIL_P(transaction)){
        |    return_value = seq_pointer->get(seq_pointer,NULL,(int32_t)delta,&next_value,flags);
        |  } else {
        |    Data_Get_Struct(transaction,DB_TXN,txn_pointer);
        |    return_value = seq_pointer->get(seq_pointer,txn_pointer,(int32_t)delta,&next_value,flags);
        |  }
        |  return (unsigned long)next_value;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |/*
        |* Closes the sequence if it is opened.
        |*/
        |void _close(){
        |  DB_SEQUENCE * seq_pointer;
        |  int return_value;
        |  Data_Get_Struct(self,DB_SEQUENCE,seq_pointer);
        |  seq_free(seq_pointer);
        |  DATA_PTR(self) = NULL;
        |}
        END
        builder.c(str.margin)
      end
    end
  end
end
