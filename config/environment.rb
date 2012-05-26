require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

$config = YAML::load(File.open("config/database.yml"))
ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

Pebblebed.config do
end
