$:.unshift "lib"
require 'rod/constants'

Gem::Specification.new do |s|
  s.name = "rod"
  s.version = Rod::VERSION
  s.date = "#{Time.now.strftime("%Y-%m-%d")}"
  s.required_ruby_version = '>= 1.9.2'
  # TODO set to Linux/MacOSX and Ruby 1.9
  s.platform    = Gem::Platform::RUBY
  s.authors = ['Aleksander Pohl']
  s.email   = ["apohllo@o2.pl"]
  s.homepage    = "http://github.com/apohllo/rod"
  s.summary = "Ruby object database"
  s.description = "Ruby object database is designed for large amount of data, whose structure rarely changes."

  s.rubyforge_project = "rod"
  s.rdoc_options = ["--main", "README.rdoc"]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_path = "lib"

  s.add_dependency("RubyInline", [">= 3.10.0","< 4.0.0"])
  s.add_dependency("english", [">= 0.5.0","< 0.6.0"])
  s.add_dependency("activemodel", ["~> 3.2.2"])
  s.add_dependency("bsearch", [">= 1.5.0","< 1.6.0"])
  s.add_development_dependency("mocha", [">= 0.9.8","< 1.0.0"])
  s.add_development_dependency("cucumber", "~> 1.0.0")
  s.add_development_dependency("rspec", [">= 2.2.0","< 2.3.0"])
  s.add_development_dependency("rake", [">= 0.9.0","< 1.0.0"])
  s.add_development_dependency("minitest", "~> 2.7.0")
end
