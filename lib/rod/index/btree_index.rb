# encoding: utf-8
require 'rod/index/base'
require 'rod/index/berkeley_index'
require 'rod/utils'

module Rod
  module Index
    # This implementation of index is based on the
    # Berkeley DB Btree access method.
    class BtreeIndex < BerkeleyIndex
      # Wrapper class for the database C struct.
      class Handle
      end

      # The class given index is associated with.
      attr_reader :klass

      # Initializes the index with +path+ and +class+.
      # Options:
      # * +:proxy_factor+ - factory used to create collection proxies
      #   (Rod::Berkeley::CollectionProxy by default).
      def initialize(path,klass,options={})
        proxy_factory = options[:proxy_factory] || Rod::Berkeley::CollectionProxy
        super(path + ".db",klass,proxy_factory)
      end

     protected

      self.inline(:C) do |builder|
        builder.include '<db.h>'
        builder.include '<stdio.h>'
        builder.include '<byteswap.h>'
        builder.include '<endian.h>'
        builder.include '<stdint.h>'
        builder.add_link_flags self.rod_link_flags
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
        |
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
        |    NULL,DB_BTREE,flags,0);
        |  if(return_value != 0){
        |    db_pointer->close(db_pointer,0);
        |    rb_raise(rodException(),"%s",db_strerror(return_value));
        |  }
        |  mod = rb_const_get(rb_cObject, rb_intern("Rod"));
        |  mod = rb_const_get(mod, rb_intern("Index"));
        |  mod = rb_const_get(mod, rb_intern("BtreeIndex"));
        |  handleClass = rb_const_get(mod, rb_intern("Handle"));
        |  // TODO the handle memory should be made free
        |  handle = Data_Wrap_Struct(handleClass,0,0,db_pointer);
        |  rb_iv_set(self,"@handle",handle);
        |}
        END
        builder.c(Utils.remove_margin(str))
      end
    end
  end
end
