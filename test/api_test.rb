require 'test_helper'

require 'rack/test'

class ApiTest < MiniTest::Test
  include Rack::Test::Methods

  def setup
    clear_collections
  end

  def app
    ExceptionistApp
  end

  def test_create_the_first_UberException
    assert_equal [], UberException.find( terms: [ { project_name: 'ExampleProject' } ] )

    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception.xml')
    assert last_response.ok?

    Exceptionist.esclient.refresh

    exce = UberException.find( terms: [ { project_name: 'ExampleProject' } ] )
    assert_equal 1, exce.count
    assert_equal 1, exce.first.occurrences_count
  end

  def test_add_occurrences_if_it_is_the_same_exception
    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception.xml')
    assert last_response.ok?

    Exceptionist.esclient.refresh

    assert_equal 1, UberException.find( terms: [ { project_name: 'ExampleProject' } ] ).count

    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception.xml')
    assert last_response.ok?

    Exceptionist.esclient.refresh

    exce = UberException.find( terms: [ { project_name: 'ExampleProject' } ] )
    assert_equal 1, exce.count
    assert_equal 2, exce.first.occurrences_count
  end

  def test_api_unauth_exception
    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/unauth_exception.xml')

    assert_equal 'Invalid API Key', last_response.body
    assert_equal 401, last_response.status

    Exceptionist.esclient.refresh

    assert_equal [], UberException.find( terms: [ { project_name: 'ExampleProject' } ] )
  end

  def test_api_full_exception
    assert_equal [], UberException.find( terms: [ { project_name: 'ExampleProject' } ] )

    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/full_exception.xml')
    assert last_response.ok?

    Exceptionist.esclient.refresh

    exce = UberException.find( terms: [ { project_name: 'ExampleProject' } ] )
    assert_equal 1, exce.count
    assert_equal 1, exce.first.occurrences_count
  end

  def test_api_exception_with_hash
    assert_equal [], UberException.find( terms: [ { project_name: 'ExampleProject' } ] )

    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception_with_hash_in_params.xml')
    assert last_response.ok?

    Exceptionist.esclient.refresh

    exce = UberException.find( terms: [ { project_name: 'ExampleProject' } ] )
    assert_equal 1, exce.count
    assert_equal 1, exce.first.occurrences_count
  end

  def test_api_minimal_exception
    assert_equal [], UberException.find( terms: [ { project_name: 'ExampleProject' } ] )

    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/minimal_exception.xml')
    assert last_response.ok?

    Exceptionist.esclient.refresh

    exce = UberException.find( terms: [ { project_name: 'ExampleProject' } ] )
    assert_equal 1, exce.count
    assert_equal 1, exce.first.occurrences_count
  end

  def test_api_deploy
    assert_equal [], Deploy.find_by_project('ExampleProject')

    post '/notifier_api/v2/deploy/', read_fixtures_file('fixtures/deploy.json')
    assert last_response.ok?

    Exceptionist.esclient.refresh

    assert_equal 1, Deploy.find_by_project('ExampleProject').count
  end

  def test_api_unauth_deploy
    post '/notifier_api/v2/deploy/', read_fixtures_file('fixtures/unauth_deploy.json')

    assert_equal 'Invalid API Key', last_response.body
    assert_equal 401, last_response.status

    Exceptionist.esclient.refresh

    assert_equal [], Deploy.find
  end
end
