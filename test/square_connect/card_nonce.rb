require 'capybara/dsl'
require 'capybara/poltergeist'

def square_pid_file
  File.join(Dir.pwd, 'square_connect.pid')
end

def start_square_connect_server
  proxy_file = File.join(Dir.pwd, 'test', 'square_connect', 'server.ru')
  IO.popen("rackup -p8000 -P#{square_pid_file} #{proxy_file} >> /dev/null 2>&1")
end

def stop_square_connect_server
  if File.exists?(square_pid_file)
    rack_pid = File.read(square_pid_file).to_i
    Process.kill('TERM', rack_pid)
  end
end

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, phantomjs_logger: '/dev/null')
end
Capybara.default_driver = :poltergeist
Capybara.app_host       = 'http://localhost:8000/'

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
