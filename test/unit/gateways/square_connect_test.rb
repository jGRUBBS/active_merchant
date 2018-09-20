require 'test_helper'

class SquareConnectTest < Test::Unit::TestCase
  include CommStub

  def setup
    @idempotency_key = SecureRandom.uuid
    @gateway         = SquareConnectGateway.new(fixtures(:square_connect))
    @credit_card     = 'CBASEDVjjlUactA8mJu5eBwMoPAgAQ'
    @amount          = 100
    @options         = {
      idempotency_key: SecureRandom.uuid,
      billing_address: address,
      currency:        'USD',
      description:     'ActiveMerchant Test Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '6ae488ff-892b-54ac-51a1-c00ec886d439|76a8675f-47b4-5fb8-49e2-73bda4f45fea', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '48b171ae-9f9f-50cd-5b0f-5dad18ebdffb|64330a9a-cd7b-5462-4f85-112406016abf', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:incorrect_cvc], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_request).returns(successful_capture_response)
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match /does not have a transaction with id/i, response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_request).returns(successful_refund_response)
    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    assert refund = @gateway.refund(@amount, '', @options)
    assert_failure refund
    assert_match /field must be set/i, refund.message
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_request).returns(successful_void_response)
    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    assert void = @gateway.void('', @options)
    assert_failure void
    assert_match /does not have a transaction with id/i, void.message
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_match /transaction approved/i, response.message
  end

  def test_failed_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_purchase_response, successful_void_response)
    assert_failure response
    assert_equal "PAYMENT_METHOD_ERROR: Card declined.", response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to connect.squareup.com:443...
      opened
      starting SSL for connect.squareup.com:443...
      SSL established
      <- "POST /v2/locations/CBASExxxxxxxxxxxxQGS9MhWrmAgAQ/transactions HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Bearer sandbox-sq0atb-xxxxxxxxxxxxE8vhrk5efg\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: connect.squareup.com\r\nContent-Length: 426\r\n\r\n"
      <- "{\"amount_money\":{\"amount\":100,\"currency\":\"USD\"},\"card_nonce\":\"CBASxxxxxxxxxxxx-KejVlnpaxEgAQ\",\"billing_address\":{\"address_line_1\":\"456 My Street\",\"address_line_2\":\"Apt 1\",\"locality\":\"Ottawa\",\"administrative_district_level_1\":\"ON\",\"postal_code\":\"K1C2N6\",\"country\":\"CA\"},\"customer_id\":null,\"idempotency_key\":\"087dcaad-6b34-49df-817d-d17a088b77f9\",\"buyer_email_address\":null,\"reference_id\":null,\"note\":null,\"delay_capture\":false}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Vary: Origin, Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Download-Options: noopen\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "X-Xss-Protection: 1; mode=block\r\n"
      -> "Date: Mon, 17 Apr 2017 22:36:29 GMT\r\n"
      -> "connection: close\r\n"
      -> "Strict-Transport-Security: max-age=631152000\r\n"
      -> "content-length: 347\r\n"
      -> "\r\n"
    )
  end

  def post_scrubbed
    %q(
      opening connection to connect.squareup.com:443...
      opened
      starting SSL for connect.squareup.com:443...
      SSL established
      <- "POST /v2/locations/[FILTERED]/transactions HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: connect.squareup.com\r\nContent-Length: 426\r\n\r\n"
      <- "{\"amount_money\":{\"amount\":100,\"currency\":\"USD\"},\"card_nonce\":\"[FILTERED]\",\"billing_address\":{\"address_line_1\":\"456 My Street\",\"address_line_2\":\"Apt 1\",\"locality\":\"Ottawa\",\"administrative_district_level_1\":\"ON\",\"postal_code\":\"K1C2N6\",\"country\":\"CA\"},\"customer_id\":null,\"idempotency_key\":\"087dcaad-6b34-49df-817d-d17a088b77f9\",\"buyer_email_address\":null,\"reference_id\":null,\"note\":null,\"delay_capture\":false}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Vary: Origin, Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Download-Options: noopen\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "X-Xss-Protection: 1; mode=block\r\n"
      -> "Date: Mon, 17 Apr 2017 22:36:29 GMT\r\n"
      -> "connection: close\r\n"
      -> "Strict-Transport-Security: max-age=631152000\r\n"
      -> "content-length: 347\r\n"
      -> "\r\n"
    )
  end

  def successful_purchase_response
    %(
      {
        "transaction": {
          "id": "6ae488ff-892b-54ac-51a1-c00ec886d439",
          "location_id": "CBASEJ6J17WEhsRglQGS9MhWrmAgAQ",
          "created_at": "2017-04-17T15:43:01Z",
          "tenders": [
            {
              "id": "76a8675f-47b4-5fb8-49e2-73bda4f45fea",
              "location_id": "CBASEJ6J17WEhsRglQGS9MhWrmAgAQ",
              "transaction_id": "6ae488ff-892b-54ac-51a1-c00ec886d439",
              "created_at": "2017-04-17T15:43:01Z",
              "note": "Online Transaction",
              "amount_money": {
                "amount":100,"currency":"USD"
              },
              "type": "CARD",
              "card_details": {
                "status": "CAPTURED",
                "card": {
                  "card_brand": "VISA",
                  "last_4": "5858"
                },
                "entry_method":"KEYED"
              }
            }
          ],
          "product": "EXTERNAL_API"
        }
      }
    )
  end

  def failed_purchase_response
    %(
      {
        "errors": [
          {
            "category": "PAYMENT_METHOD_ERROR",
            "code": "CARD_DECLINED",
            "detail": "Card declined."
          }
        ]
      }
    )
  end

  def successful_authorize_response
    %(
      {
        "transaction": {
          "id": "48b171ae-9f9f-50cd-5b0f-5dad18ebdffb",
          "location_id": "CBASEJ6J17WEhsRglQGS9MhWrmAgAQ",
          "created_at": "2017-04-18T19:11:47Z",
          "tenders": [
            {
              "id": "64330a9a-cd7b-5462-4f85-112406016abf",
              "location_id": "CBASEJ6J17WEhsRglQGS9MhWrmAgAQ",
              "transaction_id": "48b171ae-9f9f-50cd-5b0f-5dad18ebdffb",
              "created_at": "2017-04-18T19:11:47Z",
              "note": "Online Transaction",
              "amount_money": {
                "amount":100,
                "currency":"USD"
              },
              "type": "CARD",
              "card_details": {
                "status": "AUTHORIZED",
                "card": {
                  "card_brand": "VISA",
                  "last_4": "5858"
                },
                "entry_method": "KEYED"
              }
            }
          ],
          "product": "EXTERNAL_API"
        }
      }
    )
  end

  def failed_authorize_response
    %(
      {
        "errors": [
          {
            "category": "PAYMENT_METHOD_ERROR",
            "code": "VERIFY_CVV_FAILURE",
            "detail": "Card verification code check failed."
          }
        ]
      }
    )
  end

  def successful_capture_response
    %({})
  end

  def failed_capture_response
    %(
      {
        "errors": [
          {
            "category": "INVALID_REQUEST_ERROR",
            "code": "NOT_FOUND",
            "detail": "Location `CBASEJ6J17WEhsRglQGS9MhWrmAgAQ` does not have a transaction with ID `null`.",
            "field": "transaction_id"
          }
        ]
      }
    )
  end

  def successful_refund_response
    %(
      {
        "refund": {
          "id": "9fece0a2-56c3-5bff-5291-645791c6bcf7",
          "location_id": "CBASEJ6J17WEhsRglQGS9MhWrmAgAQ",
          "transaction_id": "3e3e3a23-ba75-54bf-57ba-8e79f87ec39f",
          "tender_id": "75f5bfc2-42b3-5254-7345-65f295c15f3a",
          "created_at": "2017-04-18T19: 18: 52Z",
          "reason": "Refund via API",
          "amount_money": {
            "amount": 100,
            "currency": "USD"
          },
          "status": "APPROVED"
        }
      }
    )
  end

  def failed_refund_response
    %(
      {
        "errors": [
          {
            "category": "INVALID_REQUEST_ERROR",
            "code": "MISSING_REQUIRED_PARAMETER",
            "detail": "Field must be set",
            "field": "tender_id"
          }
        ]
      }
    )
  end

  def successful_void_response
    %({})
  end

  def failed_void_response
    %(
      {
        "errors": [
          {
            "category": "INVALID_REQUEST_ERROR",
            "code": "NOT_FOUND",
            "detail": "Location `CBASEJ6J17WEhsRglQGS9MhWrmAgAQ` does not have a transaction with ID `null`.",
            "field": "transaction_id"
          }
        ]
      }
    )
  end
end
