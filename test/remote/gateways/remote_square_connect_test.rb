require 'test_helper'
require 'square_connect/card_nonce'

class RemoteSquareConnectTest < Test::Unit::TestCase

  def self.startup
    start_square_connect_server
  end

  def self.shutdown
    stop_square_connect_server
  end

  def square_card_nonce
    SquareConnectCardNonce.nonce
  end

  def setup
    @gateway = SquareConnectGateway.new(fixtures(:square_connect))

    @amount        = 100
    @credit_card   = square_card_nonce
    @declined_card = 'CBASEDVjjlUactA8mJu5eBwMoPAgAB'
    @options       = {
      idempotency_key: SecureRandom.uuid,
      billing_address: address,
      currency:        'USD',
      description:     'ActiveMerchant Test Purchase'
    }
    @success_msg = 'Transaction Approved'
    @nonce_not_found_msg = %w{
      INVALID_REQUEST_ERROR: Card nonce not found in this `sandbox` application
      environment. Please ensure an application ID belonging to the same
      environment is used for the SqPaymentForm.
    }.join(' ')
    @nonce_already_used_msg = %w{
      INVALID_REQUEST_ERROR: Card nonce already used; please request new nonce.
    }.join(' ')
    @transaction_not_found_msg = %w{
      INVALID_REQUEST_ERROR: Location `CBASEJ6J17WEhsRglQGS9MhWrmAgAQ` does not
      have a transaction with ID `null`.
    }.join(' ')
    @field_must_be_set_msg = %w{
      INVALID_REQUEST_ERROR: Field must be set
    }.join(' ')
    @invalid_request_error = [
      'INVALID_REQUEST_ERROR: Invalid response received from the Square Connect',
      'API.  (The raw response returned by the API was "")'
    ].join(' ')
    @authentication_error = %w{
      AUTHENTICATION_ERROR: The `Authorization` http header of your request was
      malformed. The header value is expected to be of the format "Bearer TOKEN"
      (without quotation marks), where TOKEN is to be replaced with your access
      token (e.g. "Bearer ABC123def456GHI789jkl0"). For more information, see
      https://docs.connect.squareup.com/api/connect/v2/#requestandresponseheaders.
      If you are seeing this error message while using one of our officially
      supported SDKs, please report this to developers@squareup.com.
    }.join(' ')
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal @success_msg, response.message
  end

  def test_successful_purchase_with_more_options
    additional_options = {
      shipping_address: address,
      email:            'joe@example.com',
      reference_id:     'TEST123456789',
      note:             'test note'
    }
    options  = @options.merge(additional_options)
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal @success_msg, response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match @nonce_not_found_msg, response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal @success_msg, capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal @nonce_not_found_msg, response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal @transaction_not_found_msg, response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal @success_msg, refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_equal @field_must_be_set_msg, response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal @success_msg, void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal @transaction_not_found_msg, response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal @success_msg, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal @nonce_not_found_msg, response.message
  end

  def test_invalid_login
    gateway = SquareConnectGateway.new(
      application_id: '',
      access_token:   '',
      location_id:    fixtures(:square_connect)[:location_id]
    )

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal @authentication_error, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card, transcript)
    assert_scrubbed(@gateway.options[:access_token], transcript)
    assert_scrubbed(@gateway.options[:location_id], transcript)
  end

end
