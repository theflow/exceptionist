require 'es_helper'
require 'app'

port = 10000

at_exit do
  ESHelper.stopCluster
end

# minitest install its own at_exit, so we need to do this after our own
require 'minitest/autorun'

Exceptionist.endpoint = "localhost:#{port}"
ESHelper.startCluster
ESHelper::ClearDB.run

# Configure
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
    exception_class:      'NameError',
    exception_message:    'NameError: undefined local variable or method dude',
    exception_backtrace:  ["[PROJECT_ROOT]/app/models/user.rb:53:in `public'", "[PROJECT_ROOT]/app/controllers/users_controller.rb:14:in `show'"],
    controller_name:      'users',
    action_name:          'show',
    project_name:         'ExampleProject',
    url:                  'http://example.com'
  }
  Occurrence.new(default_attributes.merge(attributes))
end

def create_occurrence(attributes = {})
  build_occurrence(attributes).save
end

def clear_collections
  Exceptionist.esclient.delete_by_query( match_all: {})
end

class AbstractTest < Minitest::Test
  def setup
    clear_collections
  end
end
