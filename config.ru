$:.unshift(File.dirname(__FILE__))

require 'config/environment'
require 'api/v1'
require 'rack/contrib'

ENV['RACK_ENV'] ||= 'development'

use Rack::CommonLogger
use Pebbles::Cors

map "/api/snitch/v1" do
  use Rack::PostBodyContentTypeParser
  use Rack::MethodOverride
  run SnitchV1
end
