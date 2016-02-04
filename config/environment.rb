require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

require 'rails/observers/activerecord/base'
require 'rails/observers/activerecord/observer'

require './lib/petroglyphy'
Dir.glob('./lib/**/*.rb').each{ |lib| require lib }


ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

ActiveRecord::Base.establish_connection(
  YAML::load(File.open(File.expand_path("../database.yml", __FILE__)))[environment])

ActiveRecord::Base.add_observer RiverNotifications.instance

Pebblebed.config do
end
