# encoding: utf-8

module Rod
  module Database
    module Migration
      # Migrates the database, which is located at +path+. The
      # old version of the DB is placed at +path+/backup.
      def migrate_database(path)
        raise DatabaseError.new("Database already opened.") if opened?
        @readonly = false
        @path = canonicalize_path(path)
        @metadata = load_metadata
        create_legacy_classes
        FileUtils.mkdir_p(@path + BACKUP_PREFIX)
        # Copy special classes data.
        special_classes.each do |klass|
          file = klass.path_for_data(@path)
          puts "Copying #{file} to #{@path + BACKUP_PREFIX}" if $ROD_DEBUG
          FileUtils.cp(file,@path + BACKUP_PREFIX)
        end
        Dir.glob(@path + "*").each do |file|
          # Don't move the directory itself and speciall classes data.
          unless file.to_s == @path + BACKUP_PREFIX[0..-2] ||
            special_classes.map{|c| c.path_for_data(@path)}.include?(file.to_s)
            puts "Moving #{file} to #{@path + BACKUP_PREFIX}" if $ROD_DEBUG
            FileUtils.mv(file,@path + BACKUP_PREFIX)
          end
        end
        remove_files(self.inline_library)
        self.classes.each do |klass|
          klass.send(:build_structure)
        end
        generate_c_code(@path, self.classes)
        @handler = _init_handler(@path)
        self.classes.each do |klass|
          next unless special_class?(klass) or legacy_class?(klass)
          meta = @metadata[klass.name]
          configure_count(klass,meta.count)
          next unless legacy_class?(klass)
          new_class = klass.name.sub(LEGACY_RE,"").constantize
          set_count(new_class,meta.count)
          pages = (meta.count * new_class.struct_size / _page_size.to_f).ceil
          set_page_count(new_class,pages)
        end
        _open(@handler)
        self.classes.each do |klass|
          next unless legacy_class?(klass)
          klass.migrate
          @classes.delete(klass)
        end
        path_with_date = @path + BACKUP_PREFIX[0..-2] + "_" +
          Time.new.strftime("%Y_%m_%d_%H_%M_%S") + "/"
        puts "Moving #{@path + BACKUP_PREFIX} to #{path_with_date}" if $ROD_DEBUG
        FileUtils.mv(@path + BACKUP_PREFIX,path_with_date)
        close_database
      end

      # During migration it creats the classes which are used to read
      # the legacy data.
      def create_legacy_classes
        legacy_module = nil
        begin
          legacy_module = Object.const_get(LEGACY_MODULE)
        rescue NameError
          legacy_module = Module.new
          Object.const_set(LEGACY_MODULE,legacy_module)
        end
        generate_classes(legacy_module)
        self.classes.each do |klass|
          next unless legacy_class?(klass)
          klass.model_path = BACKUP_PREFIX + klass.model_path
        end
      end

      # Returns true if the +klass+ is a legacy class, i.e.
      # a class generated during migration used to access the legacy
      # data.
      def legacy_class?(klass)
        klass.name =~ LEGACY_RE
      end
    end
  end
end
