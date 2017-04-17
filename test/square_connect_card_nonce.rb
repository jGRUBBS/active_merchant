require 'capybara/dsl'
require 'capybara/poltergeist'

timeout = 15

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(
    app,
    js_errors:        true,
    timeout:          timeout,
    window_size:      [1366, 768],
    phantomjs_logger: '/dev/null'
  )
end

Capybara.default_driver         = :poltergeist
Capybara.current_driver         = :poltergeist
Capybara.app_host               = 'http://localhost:8000/'
Capybara.javascript_driver      = :poltergeist
Capybara.default_max_wait_time  = timeout
Capybara.ignore_hidden_elements = false

module SquareConnectCardNonce
  extend Capybara::DSL

  def self.nonce
    visit('/')
    within_frame('sq-card-number') do
      find(:css, "input").set('4532 7597 3454 5858')
    end
    within_frame('sq-cvv') do
      find(:css, "input").set('111')
    end
    within_frame('sq-expiration-date') do
      find(:css, "input").set('0119')
    end
    within_frame('sq-postal-code') do
      find(:css, "input").set('94103')
    end
    find('input[type="submit"]').click

    find('#nonce-response').text
  end
end
