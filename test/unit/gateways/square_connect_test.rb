require 'test_helper'

class SquareConnectTest < Test::Unit::TestCase
  def setup
    @idempotency_key = SecureRandom.uuid
    @gateway         = SquareConnectGateway.new(fixtures(:square_connect))
    @credit_card     = 'CBASEGRUAocndA4pznp0VqN2LxYgAQ'
    @amount          = 100

    @options = {
      billing_address: {

      },
      location_id: 'CBASEJ6J17WEhsRglQGS9MhWrmAgAQ'
    }
  end

# Successful response
# {
#   "transaction": {
#     "id": "e1a174f5-30eb-5f02-5d18-78a0f81b2926",
#     "location_id": "CBASEJ6J17WEhsRglQGS9MhWrmAgAQ",
#     "created_at": "2017-04-13T21:10:31Z",
#     "tenders": [
#       {
#         "id": "d569a06d-7e6a-5f03-524d-9d4bc53e5231",
#         "location_id": "CBASEJ6J17WEhsRglQGS9MhWrmAgAQ",
#         "transaction_id": "e1a174f5-30eb-5f02-5d18-78a0f81b2926",
#         "created_at": "2017-04-13T21:10:31Z",
#         "note": "some optional note",
#         "amount_money": {
#           "amount": 100,
#           "currency": "USD"
#         },
#         "customer_id": "1234",
#         "type": "CARD",
#         "card_details": {
#           "status": "CAPTURED",
#           "card": {
#             "card_brand": "VISA",
#             "last_4": "5858"
#           },
#           "entry_method": "KEYED"
#         }
#       }
#     ],
#     "reference_id": "some optional reference id",
#     "product": "EXTERNAL_API"
#   }
# }

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'REPLACE', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
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
      Run the remote tests for this gateway, and then put the contents of transcript.log here.
    )
  end

  def post_scrubbed
    %q(
      Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
      Things to scrub:
        - Credit card number
        - CVV
        - Sensitive authentication details
    )
  end

  def successful_purchase_response
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_square_connect_test.rb \
        -n test_successful_purchase
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
