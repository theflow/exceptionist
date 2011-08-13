$LOAD_PATH.unshift File.dirname(File.expand_path(__FILE__)) + '/../lib'

require 'test/unit'
require 'rubygems'

require 'app'

##
# start our own mongodb when the tests start,
# kill it when they end
#
at_exit do
  next if $!

  if defined?(MiniTest)
    exit_code = MiniTest::Unit.new.run(ARGV)
  else
    exit_code = Test::Unit::AutoRunner.run
  end

  pid = `ps -e -o pid,command | grep [m]ongod-test`.split(" ")[0]
  puts "Killing test mongod server..."
  Process.kill("KILL", pid.to_i)
  `rm -rf /tmp/test_mongodb`
  exit exit_code
end

puts 'Starting mongod for testing at localhost:9736...'

`mkdir -p /tmp/test_mongodb`
test_dir = File.dirname(File.expand_path(__FILE__))
`mongod run --fork --logpath /dev/null --config #{test_dir}/mongod-test.conf`
sleep 1

Exceptionist.mongo = 'localhost:9736'


##
# test/spec/mini 5
# http://gist.github.com/307649
# chris@ozmm.org
#
def context(*args, &block)
  return super unless (name = args.first) && block
  require 'test/unit'
  klass = Class.new(defined?(ActiveSupport::TestCase) ? ActiveSupport::TestCase : Test::Unit::TestCase) do
    def self.test(name, &block)
      define_method("test_#{name.to_s.gsub(/\W/,'_')}", &block) if block
    end
    def self.xtest(*args) end
    def self.context(*args, &block) instance_eval(&block) end
    def self.setup(&block)
      define_method(:setup) { self.class.setups.each { |s| instance_eval(&s) } }
      setups << block
    end
    def self.setups; @setups ||= [] end
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

def build_occurrence(attributes = {})
  default_attributes = {
    :exception_class     => 'NameError',
    :exception_message   => 'NameError: undefined local variable or method dude',
    :exception_backtrace => ["[PROJECT_ROOT]/app/models/user.rb:53:in `public'", "[PROJECT_ROOT]/app/controllers/users_controller.rb:14:in `show'"],
    :controller_name     => 'users',
    :action_name         => 'show',
    :project_name        => 'ExampleProject',
    :url                 => 'http://example.com'
  }
  Occurrence.new(default_attributes.merge(attributes))
end

def create_occurrence(attributes = {})
  build_occurrence(attributes).save
end

def clear_collections
  Exceptionist.mongo.drop_collection('occurrences')
  Exceptionist.mongo.drop_collection('exceptions')
end
