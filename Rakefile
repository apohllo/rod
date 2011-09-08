$:.unshift "lib"
require 'rod/constants'

task :default => [:all_tests]

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

task :all_tests => [:test,:regression_test,:spec] do
end

desc "Run performence tests"
task :perf do
  sh "ruby tests/eff1_test.rb"
  sh "ruby tests/eff2_test.rb"
  sh "ruby tests/full_runs.rb"
end

desc "Run tests and specs"
task :test do
  sh "ruby tests/save_struct.rb"
  sh "ruby tests/load_struct.rb"
  sh "ruby tests/class_compatibility_create.rb"
  sh "ruby tests/class_compatibility_verify.rb"
  sh "ruby tests/generate_classes_create.rb"
  sh "ruby tests/generate_classes_rewrite.rb"
  sh "ruby tests/generate_classes_rewrite.rb"
  sh "ruby tests/generate_classes_verify.rb"
  sh "ruby tests/migration_create.rb"
  sh "ruby tests/migration_migrate.rb"
  sh "ruby tests/migration_verify.rb"
  sh "ruby tests/missing_class_create.rb"
  sh "ruby tests/missing_class_verify.rb"
  sh "ruby tests/unit/model.rb"
  sh "ruby tests/unit/model_tests.rb"
  sh "ruby tests/unit/database.rb"
  sh "ruby tests/unit/abstract_database.rb"
end

# Should be removed some time -- specs should cover all these cases
task :regression_test do
  sh "ruby tests/read_on_create.rb"
  sh "ruby tests/check_strings.rb"
end

task :spec do
  sh "bundle exec cucumber --tags ~@ignore features/*"
end

# Work in progress
task :wip do
  sh "bundle exec cucumber --tags @wip features/*"
end

desc "Clean"
task :clean do
  sh "rm #$gem_name*.gem" 
end

