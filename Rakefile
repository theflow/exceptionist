$LOAD_PATH.unshift 'lib'
require 'tools'

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

desc "Create MongoDB indexes"
task :create_indexes do
  Exceptionist::IndexCreator.run
end
