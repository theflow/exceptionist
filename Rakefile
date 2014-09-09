$LOAD_PATH.unshift 'lib'
require 'tools'
require 'es_helper'

task :default => :test

require 'rake/testtask'
Rake::TestTask.new do |test|
  test.libs << "test"
  test.test_files = FileList['test/**/*_test.rb']
end

desc "Remove a single exception with all occurrences completely"
task :remove_exception do
  uber_key = ENV['KEY']
  Exceptionist::Remover.run(uber_key)
end

desc "Export occurrences in json"
task :export do
  ESHelper::Exporter.run
end

desc "Import occurrences from json file"
task :import do
  ESHelper::Importer.run
end

desc "Clear DB and create index with mapping"
task :cleardb do
  ESHelper::ClearDB.run
end

desc "Print mapping"
task :mapping do
  ESHelper::Mapping.run
end
