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
gem 'bengler_test_helper',  :git => "git://github.com/bengler/bengler_test_helper.git"

group :development, :test do
  gem 'rspec', '~> 2.8'
  gem 'rack-test'
  gem 'simplecov'
  gem 'capistrano', '~> 2.9.0'
  gem 'capistrano-bengler', :git => "git@github.com:bengler/capistrano-bengler.git"
  # gem 'vcr'
  # gem 'webmock'
  # gem 'timecop'
end
