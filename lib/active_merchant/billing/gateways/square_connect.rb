module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SquareConnectGateway < Gateway
      self.live_url            = 'https://connect.squareup.com/v2'
      self.supported_countries = ['US']
      self.default_currency    = 'USD'
      self.money_format        = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url        = 'https://squareup.com/developers'
      self.display_name        = 'Sqaure Connect'

      # https://docs.connect.squareup.com/api/connect/v2/#type-errorcode
      STANDARD_ERROR_CODE_MAPPING = {
        'INVALID_CARD'              => STANDARD_ERROR_CODE[:invalid_number],
        'INVALID_EXPIRATION_YEAR'   => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'INVALID_EXPIRATION'        => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'CARD_EXPIRED'              => STANDARD_ERROR_CODE[:expired_card],
        'VERIFY_CVV_FAILURE'        => STANDARD_ERROR_CODE[:incorrect_cvc],
        'VERIFY_AVS_FAILURE'        => STANDARD_ERROR_CODE[:incorrect_zip],
        'CARD_DECLINED'             => STANDARD_ERROR_CODE[:card_declined],
        'CARD_DECLINED_CALL_ISSUER' => STANDARD_ERROR_CODE[:call_issuer],
      }

      def initialize(options = {})
        requires!(options, :application_id, :access_token, :location_id)
        super
      end

      def location_id
        @options[:location_id]
      end

      def purchase(money, payment, options = {})
        options[:delay_capture] = false
        charge(money, payment, options)
      end

      def authorize(money, payment, options = {})
        options[:delay_capture] = true
        charge(money, payment, options)
      end

      def charge(money, payment, options = {})
        requires!(options, :idempotency_key)
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)
        add_idempotency_key(post, options)
        add_optional_data(post, options)

        commit(:post, "locations/#{location_id}/transactions", post)
      end

      def capture(money, authorization, options = {})
        authorization, tender_id = authorization.split('|')
        authorization = authorization || 'null'
        path = "locations/#{location_id}/transactions/#{authorization}/capture"
        commit(:post, path)
      end

      def refund(money, authorization, options = {})
        requires!(options, :idempotency_key)
        authorization, tender_id = authorization.split('|')
        post                     = {}
        post[:idempotency_key]   = options[:idempotency_key]
        post[:tender_id]         = tender_id
        post[:reason]            = options[:reason]
        add_invoice(post, money, options)
        authorization = authorization || 'null'
        path = "locations/#{location_id}/transactions/#{authorization}/refund"
        commit(:post, path, post)
      end

      def void(authorization, options = {})
        authorization, tender_id = authorization.split('|')
        authorization = authorization || 'null'
        path = "locations/#{location_id}/transactions/#{authorization}/void"
        commit(:post, path)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((\\\"card_nonce\\\":\\\")[\w|\D]{30}), '\1[FILTERED]').
          gsub(%r((Authorization: Bearer )[\S]{#{token_size}}), '\1[FILTERED]').
          gsub(%r((\/locations\/)[a-zA-Z\d]{30}), '\1[FILTERED]')
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
        return unless options[:customer_id].present?
        post[:customer_id] = options[:customer_id].to_s
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
          amount:   amount(money).to_i,
          currency: options[:currency] || currency(money)
        }
      end

      def add_payment(post, payment)
        post[:card_nonce] = payment
      end

      def headers(options)
        {
          "Authorization" => "Bearer #{@options[:access_token]}"
        }
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        json_error(body)
      end

      def json_error(raw_response)
        msg = [
          'Invalid response received from the Square Connect API.',
          "(The raw response returned by the API was #{raw_response.inspect})"
        ].join('  ')
        {
          'errors' => [
            {
              'category' => 'INVALID_REQUEST_ERROR',
              'detail'   => msg
            }
          ]
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
        response = api_request(method, endpoint, parameters, options)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result:    avs_result,
          cvv_result:    cvv_result,
          test:          test?,
          error_code:    error_code_from(response)
        )
      end

      def avs_result
        # the response doesn't include AVS, so the 'I' is hardcoded for
        # unverified
        { code: 'D' }
      end

      def cvv_result
        # the response doesn't include CVV, so the 'I' is hardcoded for
        # unverified
        'M'
      end

      def success_from(response)
        !response.key?('errors')
      end

      def token_size
        @options[:access_token].size
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
        # FIXME: need to get tender['id'] from credit (refund) response
        return nil unless success_from(response) && response['transaction']

        response['transaction']['tenders'].map do |tender|
          "#{tender['transaction_id']}|#{tender['id']}"
        end.join(';')
      end

      def post_data(params)
        return nil unless params
        params.to_json
      end

      def error_code_from(response)
        return if success_from(response)
        error = response['errors'][0]
        if error.present?
          STANDARD_ERROR_CODE_MAPPING[error['code']]
        end
      end

    end
  end
end
