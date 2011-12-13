# -*- encoding: utf-8 -*-
require File.expand_path('../lib/omniauth-shibboleth/version', __FILE__)

Gem::Specification.new do |gem|
  gem.add_dependency 'omniauth', '~> 1.0.0.pr2'

  gem.authors       = ["Toyokazu Akiyama"]
  gem.email         = ["toyokazu@gmail.com"]
  gem.description   = %q{OmniAuth Shibboleth strategies for OmniAuth 1.0}
  gem.summary       = %q{OmniAuth Shibboleth strategies for OmniAuth 1.0}
  gem.homepage      = ""

  gem.executables   = `find bin/*`.split("\n").map{ |f| File.basename(f) }
  #gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `find .`.split("\n").map{ |f| f.gsub(/^.\//, '') }
  #gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `find test/* spec/* features/*`.split("\n")
  #gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "omniauth-shibboleth"
  gem.require_paths = ["lib"]
  gem.version       = OmniAuth::Shibboleth::VERSION
end
