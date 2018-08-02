#require 'pry-byebug'
require 'spec_helper'

def make_env(path = '/auth/shibboleth', props = {})
  {
    'REQUEST_METHOD' => 'GET',
    'PATH_INFO' => path,
    'rack.session' => {},
    'rack.input' => StringIO.new('test=true')
  }.merge(props)
end

def without_session_failure_path
  if OmniAuth::VERSION >= "1.0" && OmniAuth::VERSION < "1.1"
    "/auth/failure?message=no_shibboleth_session"
  elsif OmniAuth::VERSION >= "1.1"
    "/auth/failure?message=no_shibboleth_session&strategy=shibboleth"
  end
end

def empty_uid_failure_path
  if OmniAuth::VERSION >= "1.0" && OmniAuth::VERSION < "1.1"
    "/auth/failure?message=empty_uid"
  elsif OmniAuth::VERSION >= "1.1"
    "/auth/failure?message=empty_uid&strategy=shibboleth"
  end
end

describe OmniAuth::Strategies::Shibboleth do
  let(:app){ Rack::Builder.new do |b|
    b.use Rack::Session::Cookie, {:secret => "abc123"}
    b.use OmniAuth::Strategies::Shibboleth
    b.run lambda{|env| [200, {}, ['Not Found']]}
  end.to_app }

  context 'request phase' do
    before do
      get '/auth/shibboleth'
    end

    it 'is expected to redirect to callback_url' do
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq('/auth/shibboleth/callback')
    end
  end

  context 'callback phase' do
    context 'without Shibboleth session' do
      before do
        get '/auth/shibboleth/callback'
      end

      it 'is expected to fail to get Shib-Session-ID environment variable' do
        expect(last_response.status).to eq(302)
        expect(last_response.location).to eq(without_session_failure_path)
      end
    end

    context 'with Shibboleth session' do
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, {}) }

      it 'is expected to set default omniauth.auth fields' do
        @dummy_id = 'abcdefg'
        @eppn = 'test@example.com'
        @display_name = 'Test User'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'eppn' => @eppn, 'displayName' => @display_name)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@eppn)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq(@display_name)
      end
    end

    context 'with Shibboleth session and attribute options' do
      let(:options){ {
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => :uid,
        :name_field => :sn,
        :info_fields => {},
        :extra_fields => [:o, :affiliation] } }
      let(:app){ lambda{|env| [404, {}, ['Not Found']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected to set specified omniauth.auth fields' do
        @dummy_id = 'abcdefg'
        @uid = 'test'
        @sn = 'User'
        @organization = 'Test Corporation'
        @affiliation = 'faculty'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'sn' => @sn, 'o' => @organization, 'affiliation' => @affiliation)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@uid)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['o']).to eq(@organization)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['affiliation']).to eq(@affiliation)
      end
    end

    context 'with debug options' do
      let(:options) { { :debug => true } }
      let(:app){ lambda{|env| [404, {}, ['Not Found']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected to raise environment variables' do
        @dummy_id = 'abcdefg'
        @eppn = 'test@example.com'
        @display_name = 'Test User'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'eppn' => @eppn, 'displayName' => @display_name)
        response = strategy.call!(env)
        expect(response[0]).to eq(200)
      end
    end

    context 'with request_type = :header' do
      let(:options){ {
        :request_type => :header,
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => :uid,
        :name_field => :displayName,
        :info_fields => {},
        :extra_fields => [:o, :affiliation] } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected to handle header variables' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = 'test'
        @organization = 'Test Corporation'
        @affiliation = 'faculty'
        env = make_env('/auth/shibboleth/callback', 'HTTP_SHIB_SESSION_ID' => @dummy_id, 'HTTP_DISPLAYNAME' => @display_name, 'HTTP_UID' => @uid, 'HTTP_O' => @organization, 'HTTP_AFFILIATION' => @affiliation)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@uid)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq(@display_name)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['o']).to eq(@organization)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['affiliation']).to eq(@affiliation)
      end
    end

    context "with request_type = 'header'" do
      let(:options){ {
        :request_type => 'header',
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => :uid,
        :name_field => :displayName,
        :info_fields => {},
        :extra_fields => [:o, :affiliation] } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected to handle header variables' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = 'test'
        @organization = 'Test Corporation'
        @affiliation = 'faculty'
        env = make_env('/auth/shibboleth/callback', 'HTTP_SHIB_SESSION_ID' => @dummy_id, 'HTTP_DISPLAYNAME' => @display_name, 'HTTP_UID' => @uid, 'HTTP_O' => @organization, 'HTTP_AFFILIATION' => @affiliation)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@uid)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq(@display_name)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['o']).to eq(@organization)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['affiliation']).to eq(@affiliation)
      end
    end

    context 'with request_type = :params' do
      let(:options){ {
        :request_type => :params,
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => :uid,
        :name_field => :displayName,
        :info_fields => {},
        :extra_fields => [:o, :affiliation] } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected to handle params variables' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = 'test'
        @organization = 'Test Corporation'
        @affiliation = 'faculty'
        env = make_env('/auth/shibboleth/callback', 'QUERY_STRING' => "Shib-Session-ID=#{@dummy_id}&uid=#{@uid}&displayName=#{@display_name}&o=#{@organization}&affiliation=#{@affiliation}")
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@uid)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq(@display_name)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['o']).to eq(@organization)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['affiliation']).to eq(@affiliation)
      end
    end

    context 'with Proc option' do
      let(:options){ {
        :request_type => :env,
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => lambda {|request_param| request_param.call('eppn') || request_param.call('mail')},
        :name_field => lambda {|request_param| "#{request_param.call('cn')} #{request_param.call('sn')}"},
        :info_fields => {:affiliation => lambda {|request_param| "#{request_param.call('affiliation')}@my.localdomain" }},
        :extra_fields => [:o, :affiliation] } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected to have eppn as uid and cn + sn as name field.' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = 'test'
        @eppn = 'test@my.localdomain'
        @cn = 'Test'
        @sn = 'User'
        @organization = 'Test Corporation'
        @affiliation = 'faculty'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'eppn' => @eppn, 'cn' => @cn, 'sn' => @sn, 'o' => @organization, 'affiliation' => @affiliation)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@eppn)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq("#{@cn} #{@sn}")
        expect(strategy.env['omniauth.auth']['info']['affiliation']).to eq("#{@affiliation}@my.localdomain")
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['o']).to eq(@organization)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['affiliation']).to eq(@affiliation)
      end

      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }
      it 'is expected to have mail as uid and cn + sn as name field.' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = 'test'
        @mail = 'test@my.localdomain'
        @cn = 'Test'
        @sn = 'User'
        @organization = 'Test Corporation'
        @affiliation = 'faculty'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'mail' => @mail, 'cn' => @cn, 'sn' => @sn, 'o' => @organization, 'affiliation' => @affiliation)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@mail)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq("#{@cn} #{@sn}")
        expect(strategy.env['omniauth.auth']['info']['affiliation']).to eq("#{@affiliation}@my.localdomain")
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['o']).to eq(@organization)
        expect(strategy.env['omniauth.auth']['extra']['raw_info']['affiliation']).to eq(@affiliation)
      end
    end

    context 'empty uid with :fail_with_empty_uid = false' do
      let(:options){ {
        :request_type => :env,
        :fail_with_empty_uid => false,
        :uid_field => :uid,
        :name_field => :displayName,
        :info_fields => {} } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected to output null (empty) uid as it is' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = ''
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'displayName' => @display_name)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@uid)
      end
    end

    context 'empty uid with :fail_with_empty_uid = true' do
      let(:options){ {
        :request_type => :env,
        :fail_with_empty_uid => true,
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => :uid,
        :name_field => :displayName,
        :info_fields => {} } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected to fail because of the empty uid' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = ''
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'displayName' => @display_name)
        response = strategy.call!(env)
        expect(response[0]).to eq(302)
        expect(response[1]["Location"]).to eq(empty_uid_failure_path)
      end
    end

    context 'with :multi_values => :raw' do
      let(:options){ {
        :request_type => :env,
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => :uid,
        :name_field => :displayName,
        :info_fields => {:email => "mail"} } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected to return the raw value' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = 'test'
        @mail = 'test2\;hoge@example.com;test1\;hoge@example.com;test3\;hoge@example.com'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'displayName' => @display_name, 'mail' => @mail)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@uid)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq(@display_name)
        expect(strategy.env['omniauth.auth']['info']['email']).to eq(@mail)
      end
    end

    context 'with :multi_values => :first' do
      let(:options){ {
        :multi_values => :first,
        :request_type => :env,
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => :uid,
        :name_field => :displayName,
        :info_fields => {:email => "mail"} } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }

      it 'is expected return the first value by specifying :first' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = 'test'
        @mail = 'test2\;hoge@example.com;test1\;hoge@example.com;test3\;hoge@example.com'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'displayName' => @display_name, 'mail' => @mail)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@uid)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq(@display_name)
        expect(strategy.env['omniauth.auth']['info']['email']).to eq('test2;hoge@example.com')
      end
    end

    context 'with :multi_values => lambda function' do
      let(:options){ {
        :multi_values => "lambda {|param_value| param_value.nil? ? nil : param_value.split(/(?<!\\\\);/).sort[0].gsub('\\;',';')}",
        :request_type => :env,
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => :uid,
        :name_field => :displayName,
        :info_fields => {:email => "mail"} } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }
      it 'is expected return the processed value by specifying lambda function' do
        @dummy_id = 'abcdefg'
        @display_name = 'Test User'
        @uid = 'test'
        @mail = 'test2\;hoge@example.com;test1\;hoge@example.com;test3\;hoge@example.com'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'displayName' => @display_name, 'mail' => @mail)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@uid)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq(@display_name)
        expect(strategy.env['omniauth.auth']['info']['email']).to eq('test1;hoge@example.com')
      end
    end
    
    context 'with :force_eval_option_fields => true' do
      let(:options){ {
        :force_eval_option_fields => true,
        :request_type => :env,
        :shib_session_id_field => 'Shib-Session-ID',
        :shib_application_id_field => 'Shib-Application-ID',
        :uid_field => ":uid",
        :name_field => "lambda {|request_param| request_param.call('cn') + ' ' + request_param.call('sn')}",
        :info_fields => {:email => ":mail"} } }
      let(:app){ lambda{|env| [200, {}, ['OK']]}}
      let(:strategy){ OmniAuth::Strategies::Shibboleth.new(app, options) }
      it 'is expected return the processed value by specifying lambda function' do
        @dummy_id = 'abcdefg'
        @cn = 'Test'
        @sn = 'User'
        @display_name = 'Test User'
        @uid = 'test'
        @mail = 'hoge@example.com'
        env = make_env('/auth/shibboleth/callback', 'Shib-Session-ID' => @dummy_id, 'uid' => @uid, 'cn' => @cn, 'sn' => @sn, 'mail' => @mail)
        strategy.call!(env)
        expect(strategy.env['omniauth.auth']['uid']).to eq(@uid)
        expect(strategy.env['omniauth.auth']['info']['name']).to eq(@display_name)
        expect(strategy.env['omniauth.auth']['info']['email']).to eq('hoge@example.com')
      end
    end

  end
end
