require 'test_helper'

require 'rack/test'
require 'webrat'

Webrat.configure do |config|
  config.mode = :rack
end

class IntegrationTest < MiniTest::Test
  include Rack::Test::Methods
  include Webrat::Methods
  include Webrat::Matchers

  def setup
    clear_collections
  end

  def app
    ExceptionistApp
  end

  def test_dashboard_empty
    visit '/'
  end

  def test_dashboard_with_one_project
    occurrence = create_occurrence
    UberException.occurred(occurrence)

    Exceptionist.esclient.refresh

    visit '/'
    assert_contain 'ExampleProject'

    click_link 'ExampleProject'
  end

  def test_dashboard_with_no_deploy
    occurrence = create_occurrence
    UberException.occurred(occurrence)

    Exceptionist.esclient.refresh

    visit '/'
    assert_contain '- no deploy found'
  end

  def test_dashboard_with_deploy
    occurrence = create_occurrence
    UberException.occurred(occurrence)
    create_deploy

    Exceptionist.esclient.refresh

    visit '/'
    assert_contain '- deploy:'
  end

  def test_dashboard_with_two_projects
    occur1 = create_occurrence(project_name: 'ExampleProject')
    UberException.occurred(occur1)

    occur2 = create_occurrence(project_name: 'ExampleProject2')
    UberException.occurred(occur2)

    Exceptionist.esclient.refresh

    visit '/'
    assert_contain 'ExampleProject'
    assert_contain 'ExampleProject2'
  end

  def test_river
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)

    Exceptionist.esclient.refresh

    visit '/river'
    assert_contain 'River'
  end

  def test_river_project
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)

    Exceptionist.esclient.refresh

    visit 'projects/ExampleProject/river'
    assert_contain 'Latest Occurrences'
  end

  def test_projects_with_no_exceptions
    visit '/projects/ExampleProject'

    assert_contain 'Latest Exceptions for ExampleProject'
    assert_contain 'no exceptions'
    assert_not_contain 'next page'
    assert_not_contain 'previous page'
  end

  def test_projects_with_one_exception
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject'

    assert_contain 'Latest Exceptions for ExampleProject'
    assert_contain 'NameError in users#show'
    assert_contain '# 2'
  end

  def test_projects_pagination_latest
    27.times do |i|
      UberException.occurred(create_occurrence(action_name:"action_#{i}"))
    end

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject?sort_by=latest'
    assert_contain 'next page'
    assert_not_contain 'previous page'

    click_link 'next page'
    assert_not_contain 'next page'
    assert_contain 'previous page'
  end

  def test_projects_pagination_frequent
    27.times do |i|
      UberException.occurred(create_occurrence(action_name:"action_#{i}"))
    end

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject?sort_by=frequent'
    assert_contain 'next page'
    assert_not_contain 'previous page'

    click_link 'next page'
    assert_not_contain 'next page'
    assert_contain 'previous page'
  end

  def test_projects_be_sorted_by_most_recent
    UberException.occurred(create_occurrence(action_name:'show', occurred_at:'2010-03-01'))
    UberException.occurred(create_occurrence(action_name:'index', occurred_at:'2009-02-01'))

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject'

    # TODO: how to def test order?
    assert_contain 'NameError in users#index'
    assert_contain 'NameError in users#show'
  end

  def test_projects_show_new_exceptions
    UberException.occurred(create_occurrence(action_name:'show', occurred_at:'2010-07-01'))
    UberException.occurred(create_occurrence(action_name:'index', occurred_at:'2010-08-01'))

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject/new_on/2010-07-01?mail_to=the@dude.org'

    assert_contain 'NameError in users#show'
    assert_not_contain 'NameError in users#index'
  end

  def test_projects_forget_old_exceptions
    UberException.occurred(create_occurrence(action_name:'show', occurred_at:Time.now - (86400 * 50)))
    UberException.occurred(create_occurrence(action_name:'index', occurred_at:Time.now))

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject/forget_exceptions', :post

    assert_contain 'Deleted exceptions: 1'
  end

  def test_projects_since_last_deploy_with_no_deploy
    get '/projects/ExampleProject/since_last_deploy'

    assert !last_response.ok?
  end

  def test_projects_since_last_deploy_fresh_deploy
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)
    create_deploy

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject/since_last_deploy'

    assert_contain 'since last deploy'
    assert_contain 'no exceptions'
  end

  def test_projects_since_last_deploy_old_deploy
    create_deploy
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject/since_last_deploy'

    assert_contain 'NameError in users#show'
    assert_not_contain 'next page'
    assert_not_contain 'previous page'
  end

  def test_projects_since_last_deploy_ordered_by_occurrences_count
    create_deploy
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject/since_last_deploy?sort_by=frequent'

    assert_contain 'NameError in users#show'
    assert_not_contain 'next page'
    assert_not_contain 'previous page'
  end

  def test_projects_since_last_deploy_pagination
    create_deploy

    27.times do |i|
      UberException.occurred(create_occurrence(action_name:"action_#{i}"))
    end

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject/since_last_deploy'
    assert_contain 'since last deploy'
    assert_contain 'next page'
    assert_not_contain 'previous page'

    click_link 'next page'
    assert_contain 'since last deploy'
    assert_not_contain 'next page'
    assert_contain 'previous page'
  end

  def test_exceptions_show_a_minimal_occurrence
    occurrence = create_occurrence
    UberException.occurred(occurrence)

    Exceptionist.esclient.refresh

    visit "/exceptions/#{occurrence.uber_key}"
    assert_contain 'GET http://example.com'
    assert_contain 'NameError: undefined local variable or method dude'
    assert_contain 'Params:'
    assert_contain 'Session:'
    assert_not_contain 'Environment'
    assert_contain 'User Agent'
  end

  def test_exceptions_paginate_occurrences
    occur1 = create_occurrence(url: 'http://example.com/?show=one')
    occur2 = create_occurrence(url: 'http://example.com/?show=two')
    occur3 = create_occurrence(url: 'http://example.com/?show=three')
    UberException.occurred(occur1)
    UberException.occurred(occur2)
    UberException.occurred(occur3)

    Exceptionist.esclient.refresh

    visit "/exceptions/#{occur1.uber_key}"
    assert_contain 'Older'
    assert_contain 'Newer'
    assert_contain '3 of 3'
    assert_contain 'GET http://example.com/?show=three'
    assert_not_contain 'GET http://example.com/?show=two'

    click_link 'Older'
    assert_contain '2 of 3'
    assert_contain 'GET http://example.com/?show=two'
    assert_not_contain 'GET http://example.com/?show=three'

    click_link 'Older'
    assert_contain '1 of 3'
    assert_contain 'GET http://example.com/?show=one'
    assert_not_contain 'GET http://example.com/?show=two'
  end

  def test_projects_be_able_to_close_an_exception
    UberException.occurred(create_occurrence(action_name:'show'))
    UberException.occurred(create_occurrence(action_name:'index'))

    Exceptionist.esclient.refresh

    visit '/projects/ExampleProject'
    assert_contain 'NameError in users#show'
    assert_contain 'NameError in users#index'

    click_link 'NameError in users#show'

    click_button 'Close'

    Exceptionist.esclient.refresh

    follow_redirect!

    # redirects back to project page
    assert_equal 'http://example.org/projects/ExampleProject', last_request.url
    assert_not_contain 'NameError in users#show'
    assert_contain 'NameError in users#index'
  end

end
