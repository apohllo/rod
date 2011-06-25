$:.unshift "lib"
require 'rod/constants'

Gem::Specification.new do |s|
  s.name = "rod"
  s.version = Rod::VERSION
  s.date = "#{Time.now.strftime("%Y-%m-%d")}"
  s.summary = "Ruby object database"
  s.email = "apohllo@o2.pl"
  #s.homepage = "http://wierzba.wzks.uj.edu.pl/~mag/dilp"
  s.description = "Ruby object database is designed for large amount of data, whose structure rarely changes."
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
  s.add_development_dependency("mocha", [">= 0.9.8","< 1.0.0"])
  s.add_development_dependency("cucumber", "~> 1.0.0")
  s.add_development_dependency("rspec", [">= 2.2.0","< 2.3.0"])
end

