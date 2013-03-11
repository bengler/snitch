source 'https://rubygems.org'

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
gem 'pebbles-path'
gem 'pebbles-uid'
gem 'pebbles-cors', :git => 'git://github.com/bengler/pebbles-cors.git'

group :development, :test do
  gem 'bengler_test_helper',  :git => "git://github.com/bengler/bengler_test_helper.git", :require => false
  gem 'rspec', '~> 2.8'
  gem 'rack-test'
  gem 'simplecov'
  gem 'timecop'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn', '~> 4.1.1'
end
