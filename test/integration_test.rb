ENV['RACK_ENV'] = 'test'

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

    @exce1 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 1)))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 10)))

    @exce2 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'save'))
    @exce2.update(category: 'high')

    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'delete', url: 'http://example.com/?show=one'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 7), action_name: 'delete', url: 'http://example.com/?show=two'))
    @exce3 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 8), action_name: 'delete', url: 'http://example.com/?show=three'))
    @exce3.update(category: 'low')

    create_deploy(occurred_at: Time.local(2011, 1, 5))
    create_deploy(occurred_at: Time.local(2011, 1, 6), project_name: 'OtherProject')
    create_deploy(occurred_at: Time.local(2011, 1, 6), project_name: 'ThirdProject')

    Exceptionist.esclient.refresh
  end

  def app
    ExceptionistApp
  end

  def test_dashboard_empty
    visit '/'
  end

  def test_dashboard_contain_projects
    visit '/'
    assert_contain 'ExampleProject'
    assert_contain 'ThirdProject'

    click_link 'ExampleProject'
  end

  def test_dashboard_contain_no_deploy_message
    visit '/'
    assert_contain '- no deploy found'
  end

  def test_dashboard_contain_deploy_message
    visit '/'
    assert_contain '- deploy:'
  end

  def test_river
    visit '/river'
    assert_contain 'River'
  end

  def test_river_project
    visit 'projects/ExampleProject/river'
    assert_contain 'Latest Occurrences'
  end

  def test_projects_with_no_exceptions
    visit '/projects/PhantomProject'

    assert_contain 'Latest Exceptions for PhantomProject'
    assert_contain 'No exceptions'
    assert_not_contain 'next page'
    assert_not_contain 'previous page'
  end

  def test_projects_with_exceptions
    visit '/projects/ExampleProject'

    assert_contain 'Latest Exceptions for ExampleProject'
    assert_contain 'NameError in users#show'
    assert_contain 'NameError in users#save'
    assert_contain 'NameError in users#delete'
  end

  def test_projects_pagination_latest
    27.times do |i|
      UberException.occurred(create_occurrence(action_name:"action_#{i}", project_name: 'ThirdProject'))
    end
    Exceptionist.esclient.refresh

    visit '/projects/ThirdProject?sort_by=latest'
    assert_contain 'next page'
    assert_not_contain 'previous page'

    click_link 'next page'
    assert_not_contain 'next page'
    assert_contain 'previous page'
  end

  def test_projects_pagination_frequent
    27.times do |i|
      UberException.occurred(create_occurrence(action_name:"action_#{i}", project_name: 'ThirdProject'))
    end
    Exceptionist.esclient.refresh

    visit '/projects/ThirdProject?sort_by=frequent'
    assert_contain 'next page'
    assert_not_contain 'previous page'

    click_link 'next page'
    assert_not_contain 'next page'
    assert_contain 'previous page'
  end

  def test_projects_forget_old_exceptions
    visit '/projects/ExampleProject/forget_exceptions', :post

    assert_contain 'Deleted exceptions'
  end

  def test_projects_since_last_deploy_with_no_deploy
    assert_raises(ArgumentError) do
      get '/projects/PhantomProject/since_last_deploy'
    end
  end

  def test_projects_since_last_deploy_with_no_exceptions
    visit '/projects/ThirdProject/since_last_deploy'

    assert_contain 'since last deploy'
    assert_contain 'No exceptions'
  end

  def test_projects_since_last_deploy
    visit '/projects/ExampleProject/since_last_deploy'

    assert_contain 'NameError in users#show'
    assert_contain 'NameError in users#save'
    assert_contain 'NameError in users#delete'
    assert_not_contain 'next page'
    assert_not_contain 'previous page'
  end

  def test_projects_since_last_deploy_ordered_by_occurrences_count
    visit '/projects/ExampleProject/since_last_deploy?sort_by=frequent'

    assert_contain 'NameError in users#show'
    assert_contain 'NameError in users#save'
    assert_contain 'NameError in users#delete'
  end

  def test_projects_since_last_deploy_pagination
    27.times do |i|
      UberException.occurred(create_occurrence(action_name:"action_#{i}", project_name: 'ThirdProject'),)
    end
    Exceptionist.esclient.refresh

    visit '/projects/ThirdProject/since_last_deploy'
    assert_contain 'since last deploy'
    assert_contain 'next page'
    assert_not_contain 'previous page'

    click_link 'next page'
    assert_contain 'since last deploy'
    assert_not_contain 'next page'
    assert_contain 'previous page'
  end

  def test_projects_new_exception_since_deploy
    visit '/projects/ExampleProject'
    assert_contain 'new'
  end

  def test_projects_category_filter
    visit '/projects/ExampleProject'
    assert_have_selector '.no-category'
    assert_have_selector '.high'
    assert_have_selector '.low'

    visit '/projects/ExampleProject?category=no-category'
    assert_not_contain 'No exceptions'

    visit '/projects/ExampleProject?category=high'
    assert_not_contain 'No exceptions'

    visit '/projects/ExampleProject?category=low'
    assert_not_contain 'No exceptions'
  end

  def test_projects_since_last_deploy_filter
    visit '/projects/ExampleProject/since_last_deploy?'
    assert_have_selector '.high'
    assert_have_selector '.low'
    assert_have_selector '.no-category'

    visit '/projects/ExampleProject/since_last_deploy?category=no-category'
    assert_have_selector '.no-category'
    assert_have_no_selector '.high'

    visit '/projects/ExampleProject/since_last_deploy?category=high'
    assert_have_selector '.high'
    assert_have_no_selector '.low'

    visit '/projects/ExampleProject/since_last_deploy?category=low'
    assert_have_selector '.low'
    assert_have_no_selector '.no-category'
  end

  def test_projects_since_last_deploy_filter_sorted_by_occurrence
    visit '/projects/ExampleProject/since_last_deploy?sort_by=frequent'
    assert_have_selector '.no-category'
    assert_have_selector '.high'
    assert_have_selector '.low'

    visit '/projects/ExampleProject/since_last_deploy?category=no-category&sort_by=frequent'
    assert_have_selector '.no-category'
    assert_have_no_selector '.high'

    visit '/projects/ExampleProject/since_last_deploy?category=high&sort_by=frequent'
    assert_have_selector '.high'
    assert_have_no_selector '.low'

    visit '/projects/ExampleProject/since_last_deploy?category=low&sort_by=frequent'
    assert_have_selector '.low'
    assert_have_no_selector '.no-category'
  end

  def test_exceptions_show_a_minimal_occurrence
    visit "/exceptions/#{@exce1.id}"
    assert_contain 'GET http://example.com'
    assert_contain 'NameError: undefined local variable or method dude'
    assert_contain 'Params:'
    assert_contain 'Session:'
    assert_not_contain 'Environment'
    assert_contain 'User Agent'
  end

  def test_exceptions_paginate_occurrences
    visit "/exceptions/#{@exce3.id}"
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
    visit '/projects/ExampleProject'

    click_link 'NameError in users#show'

    submit_form 'close'
    Exceptionist.esclient.refresh
    follow_redirect!

    # redirects back to project page
    assert_equal 'http://example.org/projects/ExampleProject', last_request.url
    assert_not_contain 'NameError in users#show'
    assert_contain 'NameError in users#delete'
  end
end
