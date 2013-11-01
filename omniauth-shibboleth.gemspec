# -*- encoding: utf-8 -*-
require File.expand_path('../lib/omniauth-shibboleth/version', __FILE__)

Gem::Specification.new do |gem|
  gem.add_dependency 'omniauth', '>= 1.0.0'

  gem.add_development_dependency 'rack-test'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '>= 2.8'

  gem.license = 'MIT'

  gem.authors       = ["Toyokazu Akiyama"]
  gem.email         = ["toyokazu@gmail.com"]
  gem.description   = %q{OmniAuth Shibboleth strategies for OmniAuth 1.x}
  gem.summary       = %q{OmniAuth Shibboleth strategies for OmniAuth 1.x}
  gem.homepage      = ""

  gem.files         = `find . -not \\( -regex ".*\\.git.*" -o -regex "\\./pkg.*" -o -regex "\\./spec.*" \\)`.split("\n").map{ |f| f.gsub(/^.\//, '') }
  gem.test_files    = `find spec/*`.split("\n")
  gem.name          = "omniauth-shibboleth"
  gem.require_paths = ["lib"]
  gem.version       = OmniAuth::Shibboleth::VERSION


end
