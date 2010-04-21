require File.dirname(__FILE__) + '/test_helper'

require 'rack/test'

context 'ApiTest' do
  include Rack::Test::Methods

  def app
    ExceptionistApp
  end

  setup do
    @project = 'ExampleProject'
    Exceptionist.redis.flush_all
  end

  test 'should create the first UberException' do
    assert_equal [], UberException.find_all(@project)

    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception.xml')
    assert last_response.ok?

    uber_exceptions = UberException.find_all(@project)
    assert_equal 1, uber_exceptions.count
    assert_equal 1, uber_exceptions.first.occurrences.count
  end

  test 'should add occurrences if it is the same exception' do
    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception.xml')
    assert last_response.ok?

    assert_equal 1, UberException.find_all(@project).count

    post '/notifier_api/v2/notices/', read_fixtures_file('fixtures/exception.xml')
    assert last_response.ok?

    uber_exceptions = UberException.find_all(@project)
    assert_equal 1, uber_exceptions.count
    assert_equal 2, uber_exceptions.first.occurrences.count
  end
end
