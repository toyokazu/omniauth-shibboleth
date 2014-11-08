# OmniAuth Shibboleth strategy

OmniAuth Shibboleth strategy is an OmniAuth strategy for authenticating through Shibboleth (SAML). If you do not know OmniAuth, please visit OmniAuth wiki.

https://github.com/intridea/omniauth/wiki

The detail of the authentication middleware Shibboleth is introduced in Shibboleth wiki.

https://wiki.shibboleth.net/

OmniAuth basically works as a middleware of Rack applications. It provides environment variable named 'omniauth.auth' (auth hash) after authenticating a user. The 'auth hash' includes the user's attributes. By providing user attributes in the fixed format, applications can easily implement authentication function using multiple authentication methods.

OmniAuth Shibboleth strategy uses the 'auth hash' for providing user attributes passed by Shibboleth SP. It enables developers to use Shibboleth and the other authentication methods, including local auth, together in one application.

Currently, this document is written for Rails applications. If you tried the other environments and it requires some difficulities, please let me know in the Issues page.

https://github.com/toyokazu/omniauth-shibboleth/issues

## Getting Started

### Setup Gemfile and Install

    % cd rails-app
    % vi Gemfile
    gem 'omniauth-shibboleth'
    % bundle install

### Setup Shibboleth Strategy

To use OmniAuth Shibboleth strategy as a middleware in your rails application, add the following file to your rails application initializer directory.

    % vi config/initializer/omniauth.rb
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :shibboleth, {
        :shib_session_id_field     => "Shib-Session-ID",
        :shib_application_id_field => "Shib-Application-ID",
        :debug                     => false,
        :extra_fields => [
          :"unscoped-affiliation",
          :entitlement
        ]
      }
    end

In the above example, 'unscoped-affiliation' and 'entitlement' attributes are additionally provided in the raw_info field. They can be referred like request.env["omniauth.auth"]["extra"]["raw_info"]["unscoped-affiliation"]. The detail of the omniauth auth hash schema is described in the following page.

https://github.com/intridea/omniauth/wiki/Auth-Hash-Schema

'eppn' attribute is used as uid field. 'displayName' attribute is provided as request.env["omniauth.auth"]["info"]["name"].

These can be changed by :uid_field, :name_field option. You can also add any "info" fields defined in Auth-Hash-Schema by using :info_fields option.

    % vi config/initializer/omniauth.rb
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :shibboleth, {
        :uid_field                 => "uid",
        :name_field                => "displayName",
        :info_fields => {
          :email    => "mail",
          :location => "contactAddress",
          :image    => "photo_url",
          :phone    => "contactPhone"
        }
      }
    end

In the previous example, Shibboleth strategy does not pass any :info fields and use 'uid' attribute as uid fields.

### More flexible attribute configuration

If you need more flexible attribute definition, you can use lambda (Proc) to define your attributes. In the following example, 'uid' attribute is chosen from 'eppn' or 'mail', 'info'/'name' attribute is defined as a concatenation of 'cn' and 'sn' and 'info'/'affiliation' attribute is defined as 'affiliation'@my.localdomain. 'request_param' parameter is a method defined in OmniAuth::Shibboleth::Strategy. You can specify attribute names by downcase strings in either request_type, :env, :header and :params.

    % vi config/initializer/omniauth.rb
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :shibboleth, {
        :uid_field                 => lambda {|request_param| request_param.call('eppn') || request_param.call('mail')},
        :name_field                => lambda {|request_param| "#{request_param.call('cn')} #{request_param.call('sn')}"},
        :info_fields => {
          :affiliation => lambda {|request_param| "#{request_param.call('affiliation')}@my.localdomain"},
          :email    => "mail",
          :location => "contactAddress",
          :image    => "photo_url",
          :phone    => "contactPhone"
        }
      }
    end

### !!!NOTICE!!! devise integration issue

When you use omniauth with devise, the omniauth configuration is applied before devise configuration and some part of the configuration overwritten by the devise's. It may not work as you assume. So thus, in that case, currently you should write your configuration only in device configuration.

config/initializers/devise.rb:
```ruby
config.omniauth :shibboleth, {:uid_field => 'eppn',
                         :info_fields => {:email => 'mail', :name => 'cn', :last_name => 'sn'},
                         :extra_fields => [:schacHomeOrganization]
                  }
```

The detail is discussed in the following thread.

https://github.com/plataformatec/devise/issues/2128


### How to authenticate users

In your application, simply direct users to '/auth/shibboleth' to have them sign in via your company's Shibboleth SP and IdP. '/auth/shibboleth' url simply redirect users to '/auth/shibboleth/callback', so thus you must protect '/auth/shibboleth/callback' by Shibboleth SP.

Example shibd.conf:

    <Location /application_path/auth/shibboleth/callback>
      AuthType shibboleth
      ShibRequestSetting requireSession 1
      require valid-user
    </Location>

Shibboleth strategy just checks the existence of Shib-Session-ID or Shib-Application-ID.

If you want to use omniauth-shibboleth without Apache or IIS, you can try **rack-saml**. It supports a part of Shibboleth SP functions.

https://github.com/toyokazu/rack-saml

Shibboleth strategy assumes the attributes are provided via environment variables because the use of ShibUseHeaders option may cause some problems. The details are discussed in the following page:

https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPSpoofChecking

To provide Shibboleth attributes via environment variables, we can not use proxy based approach, e.g. mod_proxy_balancer. Currently we can realize it by using Phusion Passenger as an application container. An example construction pattern is shown in presence_checker application (https://github.com/toyokazu/presence_checker/).

### :request_type option

You understand the issues using ShibUseHeaders, but and yet if you want to use the proxy based approach, you can use :request_type option. This option enables us to specify what kind of parameters are used to create 'omniauth.auth' (auth hash). This option can also be used to develop your Rails application without local IdP and SP by using :params option. The option values are:

- **:env** (default) The environment variables are used to create auth hash.
- **:header** The auth hash is created from header vaiables. In the Rack middleware, since header variables are treated as environment variables like HTTP_*, the specified variables are converted as the same as header variables, HTTP_*. This :request_type is basically used for mod_proxy_balancer approach.
- **:params** The query string or POST parameters are used to create auth hash. This :request_type is basically used for development phase. You can emulate SP function by providing parameters as query string. In this case, please do not forget to add Shib-Session-ID or Shib-Application-ID value which is used to check the session is created at SP.

The following is an example configuration.

    % vi config/initializer/omniauth.rb
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :shibboleth, { :request_type => :header }
    end

If you use proxy based approach, please be sure to add ShibUseHeaders option in mod_shib configuration.

    <Location /secure>
      AuthType shibboleth
      ShibRequestSetting requireSession 1
      ShibUseHeaders On
      require valid-user
    </Location>

### debug mode

When you deploy a new application, you may want to confirm the assumed attributes are correctly provided by Shibboleth SP. OmniAuth Shibboleth strategy provides a confirmation option :debug. If you set :debug true, you can see the environment variables provided at the /auth/shibboleth/callback uri.

    % vi config/initializer/omniauth.rb
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :shibboleth, { :debug => true }
    end

## License (MIT License)

omniauth-shibboleth is released under the MIT license.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
