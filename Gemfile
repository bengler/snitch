source 'https://rubygems.org'

gem 'rake', '= 10.4.2'
gem 'sinatra', '= 1.4.6', require: 'sinatra/base'
gem 'sinatra-contrib', '= 1.4.6'
gem 'sinatra-activerecord', '= 2.0.9', :require => false
gem 'rack-contrib', '= 1.4.0'
gem 'rack-protection', '~> 1.5.2'
gem 'activerecord', '~> 4.2.5', :require => 'active_record'
gem 'pg', '= 0.18.4'
gem 'yajl-ruby', '= 1.2.1', :require => 'yajl'
gem 'petroglyph', '= 0.0.7'
gem 'pebblebed', '= 0.3.26'
gem 'pebbles-path', '= 0.0.3'
gem 'pebbles-uid', '= 0.0.22'
gem 'pebbles-cors', :git => 'https://github.com/bengler/pebbles-cors'
gem 'rails-observers', '= 0.1.2', require: false

group :development, :test do
  gem 'rspec', '= 3.4.0'
  gem 'rack-test', '= 0.6.3'
  gem 'simplecov', '= 0.11.1'
  gem 'timecop', '= 0.8.0'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn', '= 5.0.1'
end
