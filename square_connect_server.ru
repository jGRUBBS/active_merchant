#!/usr/bin/env rackup

require 'erb'
require 'yaml'

use Rack::ContentLength

app = Rack::Builder.app do
  use Rack::CommonLogger
  file_path   = Dir.pwd + '/index.html.erb'
  config_path = Dir.pwd + '/test/fixtures.yml'
  template    = File.read(file_path)
  config      = YAML.load(File.read(config_path))['square_connect']
  @app_id     = config['application_id']
  html        = ERB.new(template).result(binding)
  run lambda { |env| [200, {'Content-Type' => 'text/html'}, [html]] }
end

run app
