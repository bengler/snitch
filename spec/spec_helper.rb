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

# Run all examples in a transaction
RSpec.configure do |c|
  c.after(:each) do
    Timecop.return
  end
  c.around(:each) do |example|
    clear_cookies if respond_to?(:clear_cookies)
    ActiveRecord::Base.connection.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
