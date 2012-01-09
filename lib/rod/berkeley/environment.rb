require 'inline'
require 'fileutils'

module Rod
  module Berkeley
    class Environment
      # Initialization of the environment.
      def initialize
        @opened = false
      end

      # Opens the Berkeley DB environment at given +path+.
      # The following options are supported (see the Berkeley DB documentation
      # for full description of the flags):
      # * +:create+ - creates the environment if it not exist, DBD: , BDB: +DB_CREATE+
      # * +:transactions+ - initializes the transaction subsystem, BDB: +DB_INIT_TXN+
      # * +:locking+ - initializes the locking subsystem, BDB: +DB_INIT_LOCK+
      # * +:logging+ - initializes the logging subsystem, BDB: +DB_INIT_LOG+
      # * +:cache+ - initializes the environment's cache, BDB: +DB_INIT_MPOOL+
      # * +:data_store+ - initializes the concurrent data store, BDB: +DB_INIT_CDB+
      # * +:replication+ - initializes the replication subsystem, BDB: +DB_INIT_REP+
      # * +:recovery+ - runs normal recovery on the environment, BDB: +DB_RECOVER+
      # * +:fatal_recovery+ - runs fatal recovery on the environment, BDB: +DB_RECOVER_FATAL+
      # * +:lock_in_memory+ - forces the environemnt's shared data to be locked in the memory,
      #   BDB: +DB_LOCKDOWN+
      # * +:fail_check+ - checks for threads that exited leaving invalid locks or
      #   transactions, BDB: +DB_FAILCHK+
      # * +:recovery_check+ - checks if recovery has to be performed beform opening
      #   the environment, BDB: +DB_REGISTER+
      # * +:private+ - the environemnt's data might be shared only witin one process,
      #   so concurrency is allowed only between threads, BDB: +DB_PRIVATE+
      # * +:system_memory+ - use system shared memory for environment's shared data,
      #   BDB: +DB_SYSTEM_MEM+
      # * +:threads+ allow multiple threads within one process to access the
      #   environment and/or its databases, BDB: +DB_THREAD+
      def open(path,options={})
        raise DatabaseError.new("The environment at #{path} is already opened.") if opened?
        FileUtils.mkdir_p(path)
        # TODO check for conflicting options
        # TODO check for validity of options
        _open(path,options)
        @opened = true
      end

      # Closes the environment.
      def close
        _close
        @opened = false
      end

      # Returns true if the environment is opened.
      def opened?
        @opened
      end

      class << self
        # Calls methods on the C +builder+ needed to properly configure the
        # C compiler for Berkeley DB.
        def init_builder(builder)
          builder.include '<db.h>'
          builder.include '<stdio.h>'
          builder.add_compile_flags '-ldb-4.8'
        end

        # C definition of the DatabaseError.
        def database_error
          str =<<-END
          |VALUE databaseError(){
          |  VALUE klass = rb_const_get(rb_cObject, rb_intern("Rod"));
          |  klass = rb_const_get(klass, rb_intern("DatabaseError"));
          |  return klass;
          |}
          END
          str.margin
        end
      end

      inline(:C) do |builder|
        init_builder(builder)
        builder.prefix(self.database_error)

        str =<<-END
        |/*
        |* Closes the environemt causing the resources to be freed.
        |*/
        |void env_free(DB_ENV * env_pointer){
        |  int return_value;
        |  if(env_pointer != NULL){
        |    return_value = env_pointer->close(env_pointer,0);
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
        |* environment struct.
        |*/
        |VALUE allocate(){
        |  // db_mark == NULL - no internal elements have to be marked
        |  // struct == NULL - there is no struct to wrap at the moment
        |  return Data_Wrap_Struct(self,NULL,env_free,NULL);
        |}
        END
        builder.c_singleton(str.margin)

        str =<<-END
        |/*
        |* Opens the database environemnt on the path given.
        |* See +open+ for a list of options.
        |*/
        |void _open(const char * path, VALUE options){
        |  DB_ENV * env_pointer;
        |  u_int32_t flags;
        |  int return_value;
        |  // the flags has to be set to 0 - cf. db_env_create in documentation
        |  return_value = db_env_create(&env_pointer, 0);
        |  if(return_value != 0){
        |    rb_raise(databaseError(),"%s",db_strerror(return_value));
        |  }
        |  flags = 0;
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("create"))) == Qtrue){
        |    flags |= DB_CREATE;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("transactions"))) == Qtrue){
        |    flags |= DB_INIT_TXN;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("locking"))) == Qtrue){
        |    flags |= DB_INIT_LOCK;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("logging"))) == Qtrue){
        |    flags |= DB_INIT_LOG;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("cache"))) == Qtrue){
        |    flags |= DB_INIT_MPOOL;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("data_store"))) == Qtrue){
        |    flags |= DB_INIT_CDB;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("replication"))) == Qtrue){
        |    flags |= DB_INIT_REP;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("recovery"))) == Qtrue){
        |    flags |= DB_RECOVER;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("fatal_recovery"))) == Qtrue){
        |    flags |= DB_RECOVER_FATAL;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("lock_in_memory"))) == Qtrue){
        |    flags |= DB_LOCKDOWN;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("fail_check"))) == Qtrue){
        |    flags |= DB_FAILCHK;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("recovery_check"))) == Qtrue){
        |    flags |= DB_REGISTER;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("private"))) == Qtrue){
        |    flags |= DB_PRIVATE;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("system_memory"))) == Qtrue){
        |    flags |= DB_SYSTEM_MEM;
        |  }
        |  if(rb_hash_aref(options,ID2SYM(rb_intern("threads"))) == Qtrue){
        |    flags |= DB_THREAD;
        |  }
        |
        |  // use the default file access mode (last param)
        |  return_value = env_pointer->open(env_pointer,path,flags,0);
        |  if(return_value != 0){
        |    rb_raise(databaseError(),"%s",db_strerror(return_value));
        |  }
        |  DATA_PTR(self) = env_pointer;
        |}
        END
        builder.c(str.margin)

        str =<<-END
        |/*
        |* Closes the environment if it is opened.
        |*/
        |void _close(){
        |  DB_ENV * env_pointer;
        |  int return_value;
        |  Data_Get_Struct(self,DB_ENV,env_pointer);
        |  env_free(env_pointer);
        |  DATA_PTR(self) = NULL;
        |}
        END
        builder.c(str.margin)
      end
    end
  end
end
