module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SquareConnectGateway < Gateway
      self.live_url = 'https://connect.squareup.com/v2'

      self.supported_countries = ['US']
      self.default_currency    = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://connect.squareup.com'
      self.display_name = 'Sqaure Connect'

      # https://docs.connect.squareup.com/api/connect/v2/#type-errorcode
      STANDARD_ERROR_CODE_MAPPING = {
        'INVALID_CARD'              => STANDARD_ERROR_CODE[:invalid_number],
        'INVALID_EXPIRATION_YEAR'   => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'CARD_EXPIRED'              => STANDARD_ERROR_CODE[:expired_card],
        'VERIFY_CVV_FAILURE'        => STANDARD_ERROR_CODE[:incorrect_cvc],
        'CARD_DECLINED'             => STANDARD_ERROR_CODE[:card_declined],
        'CARD_DECLINED_CALL_ISSUER' => STANDARD_ERROR_CODE[:call_issuer],
      }

      def initialize(options={})
        requires!(options, :application_id, :access_token)
        super
      end

      def purchase(money, payment, options={})
        post[:delay_capture] = false
        charge(money, payment, options)
      end

      def authorize(money, payment, options={})
        post[:delay_capture] = true
        charge(money, payment, options)
      end

      def charge(money, payment, options={})
        requires!(options, :location_id, :idempotency_key)
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)
        add_idempotency_key(post, options)
        add_optional_data(post, options)

        commit(:post, "locations/#{options[:location_id]}/transactions", post)
      end

      def capture(money, authorization, options={})
        requires!(options, :location_id)
        location_id = options[:location_id]
        commit(:post, "locations/#{location_id}/transactions/#{authorization}/capture")
      end

      def refund(money, authorization, options={})
        requires!(options, :location_id, :idempotency_key)
        authorization, tender_id = authorization.split('|')
        post                     = {}
        post[:idempotency_key]   = options[:idempotency_key]
        post[:tender_id]         = tender_id
        post[:reason]            = options[:reason]
        post[:amount_money]      = money
        location_id              = options[:location_id]
        commit(:post, "locations/{location_id}/transactions/{authorization}/refund", post)
      end

      def void(authorization, options={})
        requires!(options, :location_id)
        location_id = options[:location_id]
        commit(:post, "locations/#{location_id}/transactions/#{authorization}/void")
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        # TODO:
        # true
      end

      def scrub(transcript)
        # TODO:
        # transcript
      end

      private

      def add_optional_data(post, options)
        # customer email required for chargeback protection eligibility
        post[:buyer_email_address] = options[:email]
        post[:reference_id]        = options[:reference_id]
        post[:note]                = options[:note]
        post[:delay_capture]       = options[:delay_capture]
      end

      def add_idempotency_key(post, options)
        post[:idempotency_key] = options[:idempotency_key]
      end

      def add_customer_data(post, options)
        post[:customer_id] = options[:customer_id]
      end

      def add_address(post, options)
        %i[billing_address shipping_address].each do |address_type|
          next unless address = options[address_type]
          post[address_type] = {
            address_line_1:                  address[:address1],
            address_line_2:                  address[:address2],
            locality:                        address[:city],
            administrative_district_level_1: address[:state],
            postal_code:                     address[:zip],
            country:                         address[:country]
          }
        end
      end

      def add_invoice(post, money, options)
        post[:amount_money] = {
          amount:   amount(money),
          currency: options[:currency] || currency(money)
        }
      end

      def add_payment(post, payment)
        post[:card_nonce] = payment
      end

      def headers(options)
        {
          "Authorization" => "Bearer #{access_token[:access_token]}",
          "Content-Type"  => "application/json"
        }
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def json_error(raw_response)
        msg = [
          'Invalid response received from the Square Connect API.',
          "(The raw response returned by the API was #{raw_response.inspect})"
        ].join('  ')
        {
          "error" => {
            "message" => msg
          }
        }
      end

      def api_request(method, endpoint, parameters = nil, options = {})
        url          = "#{live_url}/#{endpoint}"
        data         = post_data(parameters)
        raw_response = ssl_request(method, url, data, headers(options))
        response     = parse(raw_response)
      rescue ResponseError => e
        response     = parse(e.response.body)
      end

      def commit(method, endpoint, parameters = nil, options = {})
        response = api_request(method, url, parameters, options)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: 'I', # square doesn't return any AVS or CVV response
          cvv_result: 'P', # so the 'I' and 'P' are hardcoded for unverified
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        !response.key?('errors')
      end

      def message_from(response)
        if success_from(response)
          "Transaction Approved"
        else
          error = response['errors'][0]
          "#{error['category']}: #{error['detail']}"
        end
      end

      def authorization_from(response)
        return response["error"]["charge"] unless success

        response['transaction']['tenders'].map do |tender|
          "#{tender['transaction_id']}|#{tender['id']}"
        end.join(';')
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value != false && value.blank?
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          elsif value.is_a?(Array)
            value.map { |v| "#{key}[]=#{CGI.escape(v.to_s)}" }.join("&")
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end

      def error_code_from(response)
        unless success_from(response) && error = response['errors'][0]
          STANDARD_ERROR_CODE_MAPPING[error['code']]
        end
      end

    end
  end
end
