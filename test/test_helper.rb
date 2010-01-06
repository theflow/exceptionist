$: << File.join(File.dirname(__FILE__), '..')

require 'test/unit'
require 'rubygems'

require 'exceptionist'

##
# start our own redis when the tests start,
# kill it when they end
#
at_exit do
  next if $!

  if defined?(MiniTest)
    exit_code = MiniTest::Unit.new.run(ARGV)
  else
    exit_code = Test::Unit::AutoRunner.run
  end

  pid = `ps -e -o pid,command | grep [r]edis-test`.split(" ")[0]
  puts "Killing test redis server..."
  Process.kill("KILL", pid.to_i)
  `rm -f /tmp/test_dump.rdb`
  exit exit_code
end

test_dir = File.dirname(File.expand_path(__FILE__))
puts 'Starting redis for testing at localhost:9736...'
`redis-server #{test_dir}/redis-test.conf`
Exceptionist.redis = Redis.new(:host => '127.0.0.1', :port => 9736)


##
# test/spec/mini 3
# http://gist.github.com/25455
# chris@ozmm.org
#
def context(*args, &block)
  return super unless (name = args.first) && block
  require 'test/unit'
  klass = Class.new(defined?(ActiveSupport::TestCase) ? ActiveSupport::TestCase : Test::Unit::TestCase) do
    def self.test(name, &block)
      define_method("test_#{name.gsub(/\W/,'_')}", &block) if block
    end
    def self.xtest(*args) end
    def self.setup(&block) define_method(:setup, &block) end
    def self.teardown(&block) define_method(:teardown, &block) end
  end
  (class << klass; self end).send(:define_method, :name) { name.gsub(/\W/,'_') }
  klass.class_eval &block
end

##
# Exceptionist specific helpers
# 
def read_fixtures_file(path)
  File.read File.join(File.dirname(__FILE__), path)
end
