require 'spec_helper'

def make_env(path = '/auth/shibboleth', props = {})
  {
    'REQUEST_METHOD' => 'GET',
    'PATH_INFO' => path,
    'rack.session' => {},
    'rack.input' => StringIO.new('test=true')
  }.merge(props)
end

def failure_path
  if OmniAuth::VERSION >= "1.0" && OmniAuth::VERSION < "1.1"
    "/auth/failure?message=no_shibboleth_session"
  elsif OmniAuth::VERSION >= "1.1"
    "/auth/failure?message=no_shibboleth_session&strategy=shibboleth"
  end
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
        last_response.location.should == failure_path
      end
    end

    context 'with Shibboleth session' do
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, {}) }

      it 'should set default omniauth.auth fields' do
        @dummy_id = 'abcdefg'
        @eppn = 'test@example.com'
        @display_name = 'Test User'
        strategy.call!(make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'eppn' => @eppn, 'displayName' => @display_name))
        strategy.env['omniauth.auth']['uid'].should == @eppn
        strategy.env['omniauth.auth']['info']['name'].should == @display_name
      end
    end

    context 'with Shibboleth session and attribute options' do
      let(:options){ {
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => :uid,
        :name_field => :displayName,
        :info_fields => {},
        :extra_fields => [:o, :affiliation] } }
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

    context 'with debug options' do
      let(:options){ { :debug => true} }
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'should raise environment variables' do
        @dummy_id = 'abcdefg'
        @eppn = 'test@example.com'
        @display_name = 'Test User'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'eppn' => @eppn, 'displayName' => @display_name)
        response = strategy.call!(env)
        response[0].should == 200
      end
    end
  end
end
