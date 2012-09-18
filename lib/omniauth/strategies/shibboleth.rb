module OmniAuth
  module Strategies
    class Shibboleth
      include OmniAuth::Strategy

      option :shib_session_id_field, 'Shib-Session-ID'
      option :shib_application_id_field, 'Shib-Application-ID'
      option :uid_field, 'eppn'
      option :name_field, 'displayName'
      option :email_field, 'mail'
      option :fields, {}
      option :extra_fields, []
      option :debug, false

      def request_phase
        [ 
          302,
          {
            'Location' => script_name + callback_path + query_string,
            'Content-Type' => 'text/plain'
          },
          ["You are being redirected to Shibboleth SP/IdP for sign-in."]
        ]
      end

      def callback_phase
        if options[:debug]
          # dump attributes
          return [
            200,
            {
              'Content-Type' => 'text/plain'
            },
            [request.env.sort.map {|i| "#{i[0]}: #{i[1]}" }.join("\n")]
          ]
        end
        return fail!(:no_shibboleth_session) unless (request.env[options.shib_session_id_field.to_s] || request.env[options.shib_application_id_field.to_s])
        super
      end
      
      uid do
        request.env[options.uid_field.to_s]
      end

      info do
        res = {
          :uid   => request.env[options.uid_field.to_s],
          :name  => request.env[options.name_field.to_s],
          :email => request.env[options.email_field.to_s],
        }
        options.fields.each_pair do |k,v|
          res[k] = request.env[v.to_s]
        end
        res
      end

      extra do
        options.extra_fields.inject({:raw_info => {}}) do |hash, field|
          hash[:raw_info][field] = request.env[field.to_s]
          hash
        end
      end

    end
  end
end
