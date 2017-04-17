require 'test_helper'

class SquareConnectTest < Test::Unit::TestCase
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
    # @gateway.expects(:ssl_request).returns(failed_purchase_response)

    # response = @gateway.purchase(@amount, @credit_card, @options)
    # assert_failure response
    # assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
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
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
  end

  def failed_capture_response
  end

  def successful_refund_response
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
