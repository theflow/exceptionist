require 'test_helper'

require 'rack/test'

class ApiTest < Minitest::Test
  include Rack::Test::Methods

  def app
    ExceptionistApp
  end

  def setup
    @project = 'ExampleProject'
    clear_collections
  end

  def test_create_the_first_UberException
    assert_equal [], UberException.find_all(@project)

    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception.xml')
    assert last_response.ok?

    uber_exceptions = UberException.find_all(@project)
    assert_equal 1, uber_exceptions.count
    assert_equal 1, uber_exceptions.first.occurrences_count
  end

  def test_add_occurrences_if_it_is_the_same_exception
    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception.xml')
    assert last_response.ok?

    assert_equal 1, UberException.find_all(@project).count

    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception.xml')
    assert last_response.ok?

    uber_exceptions = UberException.find_all(@project)
    assert_equal 1, uber_exceptions.count
    assert_equal 2, uber_exceptions.first.occurrences_count
  end

  def test_check_if_api_key_is_valid
    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/unauth_exception.xml')

    assert_equal 'Invalid API Key', last_response.body
    assert_equal 401, last_response.status
    assert_equal [], UberException.find_all(@project)
  end
end
