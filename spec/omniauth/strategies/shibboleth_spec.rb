require 'spec_helper'

def make_env(path = '/auth/shibboleth', props = {})
  {
    'REQUEST_METHOD' => 'GET',
    'PATH_INFO' => path,
    'rack.session' => {},
    'rack.input' => StringIO.new('test=true')
  }.merge(props)
end

describe OmniAuth::Strategies::Shibboleth do
  let(:app){ Rack::Builder.new do |b|
    b.use Rack::Session::Cookie
    b.use OmniAuth::Strategies::Shibboleth
    b.run lambda{|env| [200, {}, ['Not Found']]}
  end.to_app }

  context 'request phase' do
    before do
      get '/auth/shibboleth'
    end

    it 'should redirect to callback_url' do
      last_response.status.should == 302
      last_response.location.should == '/auth/shibboleth/callback'
    end
  end

  context 'callback phase' do
    context 'without Shibboleth session' do
      before do
        get '/auth/shibboleth/callback'
      end

      it 'should fail to get Shib-Session-ID environment variable' do
        last_response.status.should == 302
        last_response.location.should == '/auth/failure?message=no_shibboleth_session&strategy=shibboleth'
      end
    end

    context 'with Shibboleth session' do
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, {}) }

      it 'should set default omniauth.auth fields' do
        @dummy_id = 'abcdefg'
        @eppn = 'test@example.com'
        @display_name = 'Test User'
        @email = 'test@example.com'
        strategy.call!(make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'eppn' => @eppn, 'displayName' => @display_name, 'mail' => @email))
        strategy.env['omniauth.auth']['uid'].should == @eppn
        strategy.env['omniauth.auth']['info']['name'].should == @display_name
        strategy.env['omniauth.auth']['info']['email'].should == @email
      end
    end

    context 'with Shibboleth session and attribute options' do
      let(:options){ { :uid_field => :uid, :fields => [], :extra_fields => [:o, :affiliation] } }
      let(:app){ lambda{|env| [404, {}, ['Awesome']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'should set specified omniauth.auth fields' do
        @dummy_id = 'abcdefg'
        @uid = 'test'
        @organization = 'Test Corporation'
        strategy.call!(make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'o' => @organization, 'affiliation' => @affiliation))
        strategy.env['omniauth.auth']['uid'].should == @uid
        strategy.env['omniauth.auth']['extra']['raw_info']['o'].should == @organization
        strategy.env['omniauth.auth']['extra']['raw_info']['affiliation'].should == @affiliation
      end
    end

    context 'with dev_mode options' do
      let(:options){ { :dev_mode => true} }
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'should raise environment variables' do
        @dummy_id = 'abcdefg'
        @eppn = 'test@example.com'
        @display_name = 'Test User'
        @email = 'test@example.com'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'eppn' => @eppn, 'displayName' => @display_name, 'mail' => @email)
        response = strategy.call!(env)
        response[0].should == 200
      end
    end
  end
end
