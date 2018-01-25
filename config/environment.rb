require File.expand_path('config/site.rb') if File.exists?('config/site.rb')
require "bundler"
Bundler.require
require 'rails/observers/activerecord/base'
require 'rails/observers/activerecord/observer'
require './lib/petroglyphy'
Dir.glob('./lib/**/*.rb').each{ |lib| require lib }

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']
db_config = YAML::load(File.open(File.expand_path("../database.yml", __FILE__)))
pebbles_config= {
  'development' => 'snitch.dev',
  'test' => 'snitch.dev',
  'staging' => 'amedia.staging.o5.no',
  'production' => 'amedia.o5.no'
}

ActiveRecord::Base.establish_connection(db_config[environment])
ActiveRecord::Base.add_observer RiverNotifications.instance

Pebblebed.config do
  scheme 'http'
  host pebbles_config[environment]
  service :checkpoint
end

