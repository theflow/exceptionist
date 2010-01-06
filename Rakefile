namespace :redis do
  desc "Start Redis for development"
  task :start do
    system "redis-server"
  end
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
