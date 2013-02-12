source 'http://rubygems.org'

gem 'rake'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-activerecord', :require => false
gem 'rack-contrib', :git => 'git://github.com/rack/rack-contrib.git'
gem 'rack-protection', '~> 1.3.2'
gem 'activerecord', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph'
gem 'pebblebed', '~> 0.0.44'
gem 'unicorn', '~> 4.1.1'
gem 'pebbles-path'
gem 'pebbles-uid'
gem 'pebbles-cors', :git => 'git://github.com/bengler/pebbles-cors.git'

gem 'bengler_test_helper',  :git => "git://github.com/bengler/bengler_test_helper.git"
gem 'airbrake', '~> 3.1.4', :require => false

group :development, :test do
  gem 'rspec', '~> 2.8'
  gem 'rack-test'
  gem 'simplecov'
  gem 'capistrano', '~> 2.9.0', :require => false
  gem 'capistrano-bengler', :git => "git@github.com:bengler/capistrano-bengler.git", :require => false
  # gem 'vcr'
  # gem 'webmock'
  gem 'timecop'
end
