source 'http://rubygems.org'

gem 'rake'
gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-activerecord', :require => false
gem 'rack-contrib', :git => 'git://github.com/rack/rack-contrib.git'
gem 'activerecord', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph'
gem 'pebblebed'
gem 'unicorn', '~> 4.1.1'
gem 'pebble_path'
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
  # gem 'timecop'
end
