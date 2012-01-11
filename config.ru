$:.unshift(File.dirname(__FILE__))

require 'config/environment'
require 'api/v1'
require 'config/logging'
require 'rack/contrib'

ENV['RACK_ENV'] ||= 'development'
set :environment, ENV['RACK_ENV'].to_sym

use Rack::CommonLogger

map "/api/snitch/v1" do
  use Rack::PostBodyContentTypeParser
  use Rack::MethodOverride
  run SnitchV1
end

map '/ping' do
  run lambda { |env| [200, {"Content-Type" => "application/json"}, [{name: "snitch"}.to_json]] }
end
