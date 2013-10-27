$:.unshift "lib"
require 'rod/constants'

#task :default => [:all_tests]
task :default => [:init_tests,:spec,:features]

$gem_name = "rod"

desc "Build the gem"
task :build do
  sh "gem build #$gem_name.gemspec"
  FileUtils.mkdir("pkg") unless File.exist?("pkg")
  sh "mv '#$gem_name-#{Rod::VERSION}.gem' pkg"
end

desc "Install the library at local machnie"
task :install => :build do 
  sh "gem install pkg/#$gem_name-#{Rod::VERSION}.gem"
end

desc "Push gem to rubygems"
task :push => :build do 
  sh "gem push pkg/#$gem_name-#{Rod::VERSION}.gem"
end

desc "Uninstall the library from local machnie"
task :uninstall do
  sh "sudo gem uninstall #$gem_name"
end

task :all_tests => [:init_tests,:test,:spec,:regression_test,:features]

desc "Run performence tests"
task :perf do
  sh "ruby tests/eff1_test.rb"
  sh "ruby tests/eff2_test.rb"
  sh "ruby tests/full_runs.rb"
end

desc "Run multi-step tests"
task :test do
  sh "ruby tests/save_struct.rb"
  sh "ruby tests/load_struct.rb"
  sh "ruby tests/class_compatibility_create.rb"
  sh "ruby tests/class_compatibility_verify.rb"
  sh "ruby tests/generate_classes_create.rb"
  sh "ruby tests/generate_classes_rewrite.rb"
  sh "ruby tests/generate_classes_rewrite.rb"
  sh "ruby tests/generate_classes_verify.rb"
  # TODO #206 fix index migration
  #sh "ruby tests/migration_create.rb 1000"
  #sh "ruby tests/migration_migrate.rb 1000"
  #sh "ruby tests/migration_verify.rb 1000"
  sh "ruby tests/missing_class_create.rb"
  sh "ruby tests/missing_class_verify.rb"
  sh "ruby tests/properties_order_create.rb"
  sh "ruby tests/properties_order_verify.rb"

  sh "ruby tests/unit/model_tests.rb"
  sh "ruby tests/unit/abstract_database.rb"
end

desc "Run unit tests and model specs"
task :spec do
  sh "ruby spec/property/base.rb"
  sh "ruby spec/property/field.rb"
  sh "ruby spec/property/singular_association.rb"
  sh "ruby spec/property/plural_association.rb"
  sh "ruby spec/property/virtus_adapter.rb"

  sh "ruby spec/berkeley/environment.rb"
  sh "ruby spec/berkeley/database.rb"
  sh "ruby spec/berkeley/transaction.rb"

  sh "ruby spec/native/structure_store.rb"
  sh "ruby spec/native/sequence_store.rb"

  sh "ruby spec/accessor/float_accessor.rb"
  sh "ruby spec/accessor/integer_accessor.rb"
  sh "ruby spec/accessor/object_accessor.rb"
  sh "ruby spec/accessor/singular_accessor.rb"
  sh "ruby spec/accessor/string_accessor.rb"
  sh "ruby spec/accessor/json_accessor.rb"
  sh "ruby spec/accessor/ulong_accessor.rb"

  
  sh "ruby spec/metadata/metadata.rb"
  sh "ruby spec/metadata/resource_metadata.rb"

end

# Should be removed some time -- specs should cover all these cases
task :regression_test do
  sh "ruby tests/read_on_create.rb"
  sh "ruby tests/check_strings.rb"
end

desc "Run all cucumber features without the ignored ones"
task :features do
  #sh "bundle exec cucumber --tags ~@ignore features/*"
  sh "bundle exec cucumber --tags ~@ignore features/basic.feature"
end

desc "Run only work-in-progress features"
task :wip do
  sh "bundle exec cucumber --tags @wip features/*"
end

desc "Clean all gems"
task :clean do
  sh "rm #$gem_name*.gem" 
end

desc "Show changelog from the last release"
task :changelog do
  sh "git log v#{Rod::VERSION}.. --pretty=%s | tee"
end

desc "Initialize testing environemnt"
task :init_tests do
  if File.exist?("tmp")
    sh "rm -rf tmp/*"
  else
    sh "mkdir tmp"
  end
end

desc "Compute ctags for vim"
task :ctags do
  sh "ctags -R -h rb ."
end
