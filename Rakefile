task :default => [:install]

$gem_name = "rod"

desc "Build the gem"
task :build => :test do
  sh "gem build #$gem_name.gemspec"
end

desc "Install the library at local machnie"
task :install => :build do 
  sh "sudo gem install #$gem_name"
end

desc "Uninstall the library from local machnie"
task :uninstall do
  sh "sudo gem uninstall #$gem_name"
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
  sh "ruby tests/unit/*.rb"
end

# Should be removed some time -- specs should cover all these cases
task :regression_test do
  sh "ruby tests/read_on_create.rb"
  sh "ruby tests/check_strings.rb"
end

task :spec do
  sh "bundle exec cucumber features/*"
end

desc "Clean"
task :clean do
  sh "rm #$gem_name*.gem" 
end

