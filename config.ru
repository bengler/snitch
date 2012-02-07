$:.unshift(File.dirname(__FILE__))

require 'config/environment'
require 'api/v1'
require 'config/logging'
require 'rack/contrib'

ENV['RACK_ENV'] ||= 'development'
set :environment, ENV['RACK_ENV'].to_sym

use Rack::CommonLogger

Pingable.active_record_checks!


map "/api/snitch/v1/ping" do
  use Pingable::Handler, "snitch"
end

map "/api/snitch/v1" do
  use Rack::PostBodyContentTypeParser
  use Rack::MethodOverride
  run SnitchV1
end
