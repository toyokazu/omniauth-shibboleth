require 'rspec'
require 'rack/test'
require 'omniauth'
require 'omniauth-shibboleth'

RSpec.configure do |config|
    config.include Rack::Test::Methods
    config.color_enabled = true
end
