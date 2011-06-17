$:.unshift "lib"
require 'rod/constants'

task :default => [:install]

$gem_name = "rod"

desc "Build the gem"
task :build => :all_tests do
  sh "gem build #$gem_name.gemspec"
  FileUtils.mkdir("pkg") unless File.exist?("pkg")
  sh "mv '#$gem_name-#{Rod::VERSION}.gem' pkg"
end

desc "Install the library at local machnie"
task :install => :build do 
  sh "sudo gem install pkg/#$gem_name-#{Rod::VERSION}.gem"
end

desc "Uninstall the library from local machnie"
task :uninstall do
  sh "sudo gem uninstall #$gem_name"
end

task :all_tests => [:test,:spec,:regression_test] do
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
  sh "ruby tests/create_class_compatibility.rb"
  sh "ruby tests/verify_class_compatibility.rb"
  sh "ruby tests/unit/model.rb"
  sh "ruby tests/unit/model_tests.rb"
  sh "ruby tests/unit/database.rb"
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

