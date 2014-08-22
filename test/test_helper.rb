$LOAD_PATH.unshift File.dirname(File.expand_path(__FILE__)) + '/../lib'

require 'app'

##
# start our own mongodb when the tests start,
# kill it when they end
#
at_exit do
  next if $!

  pid = `ps -e -o pid,command | grep [m]ongod-test`.split(" ")[0]
  puts "Killing test mongod server..."
  Process.kill("KILL", pid.to_i)
  `rm -rf /tmp/test_mongodb`
  exit exit_code
end

# minitest install its own at_exit, so we need to do this after our own
require 'minitest/autorun'

puts 'Starting mongod for testing at localhost:9736...'

`mkdir -p /tmp/test_mongodb`
test_dir = File.dirname(File.expand_path(__FILE__))
`mongod run --fork --logpath /dev/null --config #{test_dir}/mongod-test.conf`
sleep 1

# Configure
Exceptionist.mongo = 'localhost:9736'
Exceptionist.add_project 'ExampleProject', 'SECRET_API_KEY'
Exceptionist.add_project 'ExampleProject2', 'ANOTHER_SECRET_API_KEY'

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
