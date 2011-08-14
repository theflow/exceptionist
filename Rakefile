$LOAD_PATH.unshift 'lib'
require 'tools'

task :default => :test

require 'rake/testtask'
Rake::TestTask.new do |test|
  test.libs << "test"
  test.test_files = FileList['test/**/*_test.rb']
end

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

desc "Create MongoDB indexes"
task :create_indexes do
  Exceptionist::IndexCreator.run
end
