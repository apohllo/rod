module Rod
  module Berkeley
    class Transaction
      # The environment of the transaction.
      attr_reader :environment

      # Initializes the transaction within the given +environment+.
      def initialize(environment)
        @environment = environment
        @started = false
        @finished = false
      end

      # Begins the transaction.
      #
      # The following options are supported (see the Berkeley DB documentation
      # for full description of the flags):
      # * +:read_committed: - degree 2 isolation of the transaction,
      #   BDB: +DB_READ_COMMITTED+
      # * +:read_uncommitted: - degree 1 isolation of the transaction,
      #   BDB: +DB_READ_UNCOMMITTED+
      # * +:bulk: - enable transactional bulk insert, NOT SUPPORTED!
      #   BDB: +DB_TXN_BULK+
      # * +:no_sync: - do not flush synchronously to the log (ACI without D),
      #   BDB: +DB_TXN_NOSYNC+
      # * +:no_wait: - raises exception if can't obtain a lock immediately,
      #   BDB: +DB_TXN_NOWAIT+
      # * +:snapshot: - snapshot isolation of the transaction,
      #   BDB: +DB_TXN_SNAPSHOT+
      # * +:sync: - (default) flush synchronously to the log (full ACID),
      #   BDB: +DB_TXN_SYNC+
      # * +:wait: - (default) wait for locks if they are not available,
      #   BDB: +DB_TXN_WAIT+
      # * +:write_no_sync: - write to the log but don't flush it, similar to
      #   +:no_sync+, BDB: +DB_TXN_WRITE_NOSYNC+
      def begin(options={})
        raise DatabaseError.new("The transaction has already started.") if started?
        _begin(options)
        @started = true
      end

      # Returns true if the transaction was started.
      def started?
        @started
      end

      # Returns true if the transaction was finished.
      def finished?
        @finished
      end

      # Restarts the transaction if it was finished.
      # This allows for preservation of resources.
      def reset
        raise DatabaseError.new("Transaction not finished!") if started? && !finished?
        @started = false
        @finished = false
      end

      # Aborts the transaction if it was started and not finished otherwise
      # leaves it as it is.
      def finish
        return unless started?
        return if finished?
        self.abort
      end

      # Commit the transaction.
      #
      # The following options are supported (see the Berkeley DB documentation
      # for full description of the flags):
      # * +:no_sync: - do not flush synchronously to the log (ACI without D),
      #   BDB: +DB_TXN_NOSYNC+
      # * +:sync: - (default) flush synchronously to the log (full ACID),
      #   BDB: +DB_TXN_SYNC+
      # * +:write_no_sync: - write to the log but don't flush it, similar to
      #   +:no_sync+, BDB: +DB_TXN_WRITE_NOSYNC+
      def commit(options={})
        raise DatabaseError.new("The transaction has not been started!") unless started?
        _commit(options)
        @finished = true
      end

      # Abort the transaction.
      def abort
        raise DatabaseError.new("The transaction has not been started!") unless started?
        _abort
        @finished = true
      end

      inline(:C) do |builder|
        Rod::Berkeley::Environment.init_builder(builder)
        builder.prefix(Rod::Berkeley::Environment.database_error)

        str =<<-END
        |/*
        |* Aborts the transaction causing the resources to be freed.
        |*/
        |void txn_free(DB_TXN * txn_pointer){
        |  int return_value;
        |
        |  if(txn_pointer != NULL){
        |    return_value = txn_pointer->abort(txn_pointer);
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
        |* transaction struct.
        |*/
        |VALUE allocate(){
        |  // db_mark == NULL - no internal elements have to be marked
        |  // struct == NULL - there is no struct to wrap at the moment
        |  return Data_Wrap_Struct(self,NULL,txn_free,NULL);
        |}
        END
        builder.c_singleton(str.margin)

        str =<<-END
        |/*
        |* Starts the transaction. See +start+ for a list of options.
        |*/
        |void _begin(VALUE options){
        |  DB_ENV * env_pointer;
        |  DB_TXN * txn_pointer;
        |  u_int32_t flags;
        |  int return_value;
        |  VALUE environment;
        |
        |  environment = rb_iv_get(self,"@environment");
        |  if(NIL_P(environment)){
        |    rb_raise(databaseError(),"The environment of the transaction is nil!");
        |  }
        |  Data_Get_Struct(environment,DB_ENV,env_pointer);
        |  if(env_pointer == NULL){
        |    rb_raise(databaseError(),"The environment of the transaction is NULL!");
        |  }
        |  flags = 0;
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("read_committed"))) == Qtrue){
        |    flags |= DB_READ_COMMITTED;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("read_uncommitted"))) == Qtrue){
        |    flags |= DB_READ_UNCOMMITTED;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("bulk"))) == Qtrue){
        |    // Not supported yet.
        |    //flags |= DB_TXN_BULK;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("no_sync"))) == Qtrue){
        |    flags |= DB_TXN_NOSYNC;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("no_wait"))) == Qtrue){
        |    flags |= DB_TXN_NOWAIT;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("snapshot"))) == Qtrue){
        |    flags |= DB_TXN_SNAPSHOT;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("sync"))) == Qtrue){
        |    flags |= DB_TXN_SYNC;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("wait"))) == Qtrue){
        |    flags |= DB_TXN_WAIT;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("write_no_sync"))) == Qtrue){
        |    flags |= DB_TXN_WRITE_NOSYNC;
        |  }
        |  // 1 NULL - parent transaction (not implemented yet)
        |  return_value = env_pointer->txn_begin(env_pointer,NULL,&txn_pointer,flags);
        |  if(return_value != 0){
        |    rb_raise(databaseError(),"%s",db_strerror(return_value));
        |  }
        |  DATA_PTR(self) = txn_pointer;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |/*
        |* Commit the transaction.
        |*/
        |void _commit(VALUE options){
        |  DB_TXN * txn_pointer;
        |  int return_value;
        |  u_int32_t flags;
        |
        |  Data_Get_Struct(self,DB_TXN,txn_pointer);
        |
        |  flags = 0;
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("no_sync"))) == Qtrue){
        |    flags |= DB_TXN_NOSYNC;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("sync"))) == Qtrue){
        |    flags |= DB_TXN_SYNC;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("write_no_sync"))) == Qtrue){
        |    flags |= DB_TXN_WRITE_NOSYNC;
        |  }
        |
        |  if(txn_pointer != NULL){
        |    return_value = txn_pointer->commit(txn_pointer,flags);
        |    if(return_value != 0){
        |      rb_raise(databaseError(),"%s",db_strerror(return_value));
        |    }
        |  }
        |  DATA_PTR(self) = NULL;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |/*
        |* Abort the transaction.
        |*/
        |void _abort(){
        |  DB_TXN * txn_pointer;
        |  int return_value;
        |
        |  Data_Get_Struct(self,DB_TXN,txn_pointer);
        |  txn_free(txn_pointer);
        |  DATA_PTR(self) = NULL;
        |}
        END
        builder.c(str.margin)
      end
    end
  end
end
