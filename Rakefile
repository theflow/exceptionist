$LOAD_PATH.unshift 'lib'

task :default => :test

require 'rake/testtask'
Rake::TestTask.new do |test|
  test.libs << "test"
  test.test_files = FileList['test/**/*_test.rb']
end
