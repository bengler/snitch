require 'simplecov'
require 'timecop'

SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

$:.unshift(File.dirname(File.dirname(__FILE__)))

ENV["RACK_ENV"] = "test"
require 'config/environment'

require 'rack/test'

require 'api/v1'

set :environment, :test

# Run all examples in a transaction
RSpec.configure do |c|
  c.before(:each) do
    Time.zone = "Europe/Oslo"
    ActiveRecord::Base.time_zone_aware_attributes = true
    ActiveRecord::Base.default_timezone = "Europe/Oslo"
  end
  c.after(:each) do
    Timecop.return
  end
  c.around(:each) do |example|
    clear_cookies if respond_to?(:clear_cookies)
#    $memcached = Mockcached.new
    ActiveRecord::Base.connection.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
