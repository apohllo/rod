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

desc "Run tests and spec"
task :test do
  sh "ruby tests/save_struct.rb"
  sh "ruby tests/load_struct.rb"
  sh "ruby tests/save_zero_string.rb"
  sh "ruby tests/load_zero_string.rb"
  sh "ruby tests/full_runs.rb"
end

desc "Clean"
task :clean do
  sh "rm #$gem_name*.gem" 
end

