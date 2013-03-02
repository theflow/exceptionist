$LOAD_PATH.unshift 'lib'
require 'tools'

task :default => :test

require 'rake/testtask'
Rake::TestTask.new do |test|
  test.libs << "test"
  test.test_files = FileList['test/**/*_test.rb']
end

desc "Create MongoDB indexes"
task :create_indexes do
  Exceptionist::IndexCreator.run
end
