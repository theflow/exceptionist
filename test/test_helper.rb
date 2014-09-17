require 'simplecov'
SimpleCov.start do
  add_filter 'test'
end

require 'app'
require 'elasticsearch/extensions/test/cluster'


at_exit do
  Elasticsearch::Extensions::Test::Cluster.stop( port: Exceptionist.esclient.port )
end

# minitest install its own at_exit, so we need to do this after our own
require 'minitest/autorun'

Exceptionist.endpoint = "localhost:10000"
Elasticsearch::Extensions::Test::Cluster.start(
    cluster_name: "testing-cluster",
    port: Exceptionist.esclient.port,
    nodes: 1,
)

Exceptionist.esclient.create_indices('exceptionist', YAML.load(File.read('lib/mapping.yaml') ))
Exceptionist.esclient.refresh

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

def build_deploy(attributes = {})
  default_attributes = {
      project_name: 'ExampleProject',
      api_key: 'SECRET_API_KEY',
      version: '0.0.1',
      changelog_link: 'https://github.com/podio/podio-rb/commit/35b1bbaaafd56b200ee4a0ea38fc13dfdea8304e'
  }
  Deploy.new(default_attributes.merge(attributes))
end

def create_deploy(attributes = {})
  build_deploy(attributes).save
end

def clear_collections
  Exceptionist.esclient.delete_by_query
end

class AbstractTest < Minitest::Test
  def setup
    clear_collections
  end
end
