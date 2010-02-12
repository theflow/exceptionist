require 'tools'

namespace :redis do
  desc "Start Redis for development"
  task :start do
    system "redis-server"
  end
end

desc "Export occurrences in json"
task :export do
  Exceptionist::Exporter.run
end

desc "Import occurrences from json log file"
task :import do
  Exceptionist::Importer.run
end

desc "Purge Exceptionist data from redis"
task :reset do
  Exceptionist::Reseter.run
end

desc "Export, reset and reimport"
task :reimport do
  Exceptionist::Exporter.run
  Exceptionist::Reseter.run
  Exceptionist::Importer.run
end

desc "Run tests"
task :test do
  # Don't use the rake/testtask because it loads a new
  # Ruby interpreter - we want to run tests with the current
  # `rake` so our library manager still works
  Dir['test/*_test.rb'].each do |f|
    require f
  end
end
