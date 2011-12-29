module OmniAuth
  module Strategies
    class Shibboleth
      include OmniAuth::Strategy

      option :uid_field, :eppn
      option :fields, [:name, :email]
      option :extra_fields, []
      option :dev_mode, false

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
        if options[:dev_mode]
          # dump attributes
          return [
            200,
            {
              'Content-Type' => 'text/plain'
            },
            [request.env.sort.map {|i| "#{i[0]}: #{i[1]}" }.join("\n")]
          ]
        end
        return fail!(:no_shibboleth_session) unless (request.env['Shib-Session-ID'] || request.env['Shib-Application-ID'])
        super
      end
      
      uid do
        request.env[options.uid_field.to_s]
      end

      info do
        options.fields.inject({}) do |hash, field|
          case field
          when :name
            hash[field] = request.env['displayName']
          when :email
            hash[field] = request.env['mail']
          else
            hash[field] = request.env[field.to_s]
          end
          hash
        end
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
