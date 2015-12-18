$:.unshift(File.dirname(__FILE__))

require './config/environment'
require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'

task :environment do
  require 'config/environment'
end

# TODO: This exists only so CI server will find the task. Change CI
#   script so we don't need it.  desc "purge expired claims"
namespace :test do
  desc "Prepare test database."
  task :prepare
end

namespace :db do


  desc "bootstrap db user, recreate, run migrations"
  task :bootstrap do
    name = "snitch"
    `createuser -sdR #{name}`
    `createdb -O #{name} #{name}_development`
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:test:prepare'].invoke
  end

  task :migrate => :environment

  desc "nuke db, recreate, run migrations"
  task :nuke do
    name = "snitch"
    `dropdb #{name}_development`
    `createdb -O #{name} #{name}_development`
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:test:prepare'].invoke
  end

  desc "add seed data to database"
  task :seed => :environment do
    require_relative './db/seeds'
  end
end
