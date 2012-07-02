module Rod
  module Model
    module Migration
      # Migrates the class to the new model, i.e. it copies all the
      # values of properties that both belong to the class in the old
      # and the new model; it initializes new properties with default
      # values and migrates the indices to different implementations.
      def migrate
        # check if the migration is needed
        old_metadata = self.metadata
        old_metadata.merge!({:superclass => old_metadata[:superclass].sub(LEGACY_RE,"")})
        new_class = self.name.sub(LEGACY_RE,"").constantize
        if new_class.compatible?(old_metadata)
          backup_path = self.path_for_data(database.path)
          new_path = new_class.path_for_data(database.path)
          puts "Copying #{backup_path} to #{new_path}" if $ROD_DEBUG
          FileUtils.cp(backup_path,new_path)
          new_class.indexed_properties.each do |property|
            backup_path = self.property(property.name).index.path
            new_path = property.index.path
            puts "Copying #{backup_path} to #{new_path}" if $ROD_DEBUG
            FileUtils.cp(backup_path,new_path)
          end
          return
        end
        database.send(:allocate_space,new_class)

        puts "Migrating #{new_class}" if $ROD_DEBUG
        # Check for incompatible properties.
        self.properties.each do |name,property|
          next unless new_class.property(name)
          difference = property.difference(new_class.properties[name])
          difference.delete(:index)
          # Check if there are some options which we cannot migrate at the
          # moment.
          unless difference.empty?
            raise IncompatibleVersion.
              new("Incompatible definition of property '#{name}'\n" +
                  "Definition of '#{name}' is different in the old and "+
                  "the new schema for '#{new_class}':\n" +
                  "  #{difference}")
          end
        end
        # Migrate the objects.
        # initialize prototype objects
        old_object = self.new
        new_object = new_class.new
        self.properties.each do |property|
          # optimization
          name = property.name.to_s
          next unless new_class.property(name.to_sym)
          print "-  #{name}... " if $ROD_DEBUG
          if property.field?
            if property.variable_size?
              self.count.times do |position|
                new_object.send("_#{name}_length=",position+1,
                                old_object.send("_#{name}_length",position+1))
                new_object.send("_#{name}_offset=",position+1,
                                old_object.send("_#{name}_offset",position+1))
                report_progress(position,self.count) if $ROD_DEBUG
              end
            else
              self.count.times do |position|
                new_object.send("_#{name}=",position + 1,
                                old_object.send("_#{name}",position + 1))
                report_progress(position,self.count) if $ROD_DEBUG
              end
            end
          elsif property.singular?
            self.count.times do |position|
              new_object.send("_#{name}=",position + 1,
                              old_object.send("_#{name}",position + 1))
              report_progress(position,self.count) if $ROD_DEBUG
            end
            if property.polymorphic?
              self.count.times do |position|
                new_object.send("_#{name}__class=",position + 1,
                                old_object.send("_#{name}__class",position + 1))
                report_progress(position,self.count) if $ROD_DEBUG
              end
            end
          else
            self.count.times do |position|
              new_object.send("_#{name}_count=",position + 1,
                              old_object.send("_#{name}_count",position + 1))
              new_object.send("_#{name}_offset=",position + 1,
                              old_object.send("_#{name}_offset",position + 1))
              report_progress(position,self.count) if $ROD_DEBUG
            end
          end
          puts " done" if $ROD_DEBUG
        end
        # Migrate the indices.
        new_class.indexed_properties.each do |property|
          # Migrate to new options.
          old_index_type = self.property(property.name) &&
            self.property(property.name).options[:index]
          if old_index_type.nil?
            print "-  building index #{property.options[:index]} for '#{property.name}'... " if $ROD_DEBUG
            new_class.rebuild_index(property)
            puts " done" if $ROD_DEBUG
          elsif property.options[:index] == old_index_type
            backup_path = self.property(property.name).index.path
            new_path = property.index.path
            puts "Copying #{backup_path} to #{new_path}" if $ROD_DEBUG
            FileUtils.cp(backup_path,new_path)
          else
            print "-  copying #{property.options[:index]} index for '#{property.name}'... " if $ROD_DEBUG
            new_index = property.index
            old_index = self.property(property.name).index
            new_index.copy(old_index)
            puts " done" if $ROD_DEBUG
          end
        end
      end
    end
  end
end
