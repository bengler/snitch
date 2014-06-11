source 'https://rubygems.org'

gem 'rake'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-activerecord', :require => false
gem 'rack-contrib', :git => 'https://github.com/rack/rack-contrib'
gem 'rack-protection', '~> 1.3.2'
gem 'activerecord', '~> 3.2.18', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph'
gem 'pebblebed', '~> 0.1.3'
gem 'pebbles-path'
gem 'pebbles-uid'
gem 'pebbles-cors', :git => 'https://github.com/bengler/pebbles-cors'

group :development, :test do
  gem 'bengler_test_helper',  :git => "https://github.com/bengler/bengler_test_helper", :require => false
  gem 'rspec'
  gem 'rack-test'
  gem 'simplecov'
  gem 'timecop'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn', '~> 4.1.1'
end
