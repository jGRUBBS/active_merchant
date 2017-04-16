module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SquareConnectGateway < Gateway
      self.live_url = 'https://connect.squareup.com/v2'

      self.supported_countries = ['US']
      self.default_currency    = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://connect.squareup.com'
      self.display_name = 'Sqaure Connect'

      SUPPORT_EMAIL = 'support@squareup.com'
      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :application_id, :access_token)
        super
      end

      def purchase(money, payment, options={})
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

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)
        add_idempotency_key(post, options)
        add_optional_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_optional_data(post, options)
        post[:reference_id]  = options[:reference_id]
        post[:note]          = options[:note]
        post[:delay_capture] = options[:delay_capture]
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
          "Please contact #{SUPPORT_EMAIL} if you continue to receive this message.",
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
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
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
      end

      def post_data(action, parameters = {})
      end

      def error_code_from(response)
        unless success_from(response)
          error = response.fetch('errors', nil)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
