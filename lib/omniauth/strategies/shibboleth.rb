module OmniAuth
  module Strategies
    class Shibboleth
      include OmniAuth::Strategy

      option :shib_session_id_var, 'Shib-Session-ID'
      option :shib_application_id_var, 'Shib-Application-ID'
      option :fields, {:uid => 'eppn', :name => 'displayName' , :email => 'mail'}
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
        return fail!(:no_shibboleth_session) unless (request.env[options.shib_session_id_var] || request.env[options.shib_application_id_var])
        super
      end
      
      uid do
        request.env[options.fields.uid.to_s]
      end

      info do
        res = {}
        options.fields.each_pair do |k,v|
          res[k] = request.env[v]
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
