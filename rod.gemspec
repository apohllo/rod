Gem::Specification.new do |s|
  s.name = "rod"
  #s.version = "0.3.1.snapshot#{`git log -1 --pretty="format:%at"`.chomp}"
  s.version = "0.4.3"
  s.date = "#{Time.now}"
  s.summary = "Ruby read-only object database"
  s.email = "apohllo@o2.pl"
  #s.homepage = "http://wierzba.wzks.uj.edu.pl/~mag/dilp"
  s.description = "Ruby read-only object database with nice interface"
  s.require_path = "lib"
  s.has_rdoc = true
  s.authors = ['Aleksander Pohl', 'Piotr Gurgul', 'Marcin Sieniek']
  s.files = ["Rakefile", "rod.gemspec", 'lib/rod.rb', 'README', 
    'changelog.txt', 'Gemfile'] + Dir.glob("lib/**/*")
  #s.test_files = Dir.glob("{test,spect}/**/*")
  #s.rdoc_options = ["--main", "README.txt"]
  #s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.add_dependency("RubyInline", [">= 3.8.3","< 4.0.0"])
  s.add_dependency("english", [">= 0.5.0","< 0.6.0"])
  s.add_dependency("activemodel", [">= 3.0.7","< 3.1.0"])
  s.add_dependency("weak_hash", ["= 1.0.1"])
  s.add_development_dependency("mocha", [">= 0.9.8","< 1.0.0"])
  s.add_development_dependency("cucumber", [">= 0.9.4","< 0.10.0"])
  s.add_development_dependency("rspec", [">= 2.2.0","< 2.3.0"])
end

