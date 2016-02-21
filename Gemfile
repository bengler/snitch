source 'https://rubygems.org'

gem 'rake'
gem 'sinatra', require: 'sinatra/base'
gem 'sinatra-contrib'
gem 'sinatra-activerecord', :require => false
gem 'rack-contrib'
gem 'rack-protection', '~> 1.5.2'
gem 'activerecord', '~> 4.2.5', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph'
gem 'pebblebed'
gem 'pebbles-path'
gem 'pebbles-uid'
gem 'pebbles-cors', :git => 'https://github.com/bengler/pebbles-cors'
gem 'rails-observers', '~> 0.1', require: false

group :development, :test do
  gem 'rspec'
  gem 'rack-test'
  gem 'simplecov'
  gem 'timecop'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn'
end
