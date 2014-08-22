require 'test_helper'

require 'rack/test'
require 'webrat'

Webrat.configure do |config|
  config.mode = :rack
end

class IntegrationTest < Minitest::Test
  include Rack::Test::Methods
  include Webrat::Methods
  include Webrat::Matchers

  def app
    ExceptionistApp
  end

  def setup
    clear_collections
  end

  def test_show_a_empty_dashboard
    visit '/'
  end

  def test_show_the_dashboard_with_one_project
    occurrence = create_occurrence
    UberException.occurred(occurrence)

    visit '/'
    assert_contain 'ExampleProject'

    click_link 'ExampleProject'
  end

  def test_show_the_dashboard_with_two_projects
    occurrence1 = create_occurrence(:project_name => 'ExampleProject')
    UberException.occurred(occurrence1)

    occurrence2 = create_occurrence(:project_name => 'ExampleProject2')
    UberException.occurred(occurrence2)

    visit '/'
    assert_contain 'ExampleProject'
    assert_contain 'ExampleProject2'
  end

  def test_with_one_exception
    UberException.occurred(create_occurrence)
    UberException.occurred(create_occurrence)

    visit '/projects/ExampleProject'

    assert_contain 'Latest Exceptions for ExampleProject'
    assert_contain 'NameError in users#show'
    assert_contain '# 2'
  end

  def test_with_pagination
    27.times do |i|
      UberException.occurred(create_occurrence(:action_name => "action_#{i}"))
    end

    visit '/projects/ExampleProject'
    assert_contain 'next page'
    assert_not_contain 'previous page'

    click_link 'next page'
    assert_not_contain 'next page'
    assert_contain 'previous page'
  end

  def test_be_sorted_by_most_recent
    UberException.occurred(create_occurrence(:action_name => 'show', :occurred_at => '2010-03-01'))
    UberException.occurred(create_occurrence(:action_name => 'index', :occurred_at => '2009-02-01'))

    visit '/projects/ExampleProject'

    # TODO: how to def test order?
    assert_contain 'NameError in users#index'
    assert_contain 'NameError in users#show'
  end

  def test_show_new_exceptions
    UberException.occurred(create_occurrence(:action_name => 'show', :occurred_at => '2010-07-01'))
    UberException.occurred(create_occurrence(:action_name => 'index', :occurred_at => '2010-08-01'))

    visit '/projects/ExampleProject/new_on/2010-07-01?mail_to=the@dude.org'

    assert_contain 'NameError in users#show'
    assert_not_contain 'NameError in users#index'
  end

  def test_forget_old_exceptions
    UberException.occurred(create_occurrence(:action_name => 'show', :occurred_at => Time.now - (86400 * 50)))
    UberException.occurred(create_occurrence(:action_name => 'index', :occurred_at => Time.now))

    visit '/projects/ExampleProject/forget_exceptions', :post

    assert_contain 'Deleted exceptions: 1'
  end

  def test_show_a_minimal_occurrence
    occurrence = create_occurrence
    UberException.occurred(occurrence)

    visit "/exceptions/#{occurrence.uber_key}"
    assert_contain 'GET http://example.com'
    assert_contain 'NameError: undefined local variable or method dude'
    assert_contain 'Params:'
    assert_contain 'Session:'
    assert_not_contain 'Environment'
    assert_contain 'User Agent'
  end

  def test_paginate_occurrences
    occurrence1 = create_occurrence(:url => 'http://example.com/?show=one')
    occurrence2 = create_occurrence(:url => 'http://example.com/?show=two')
    occurrence3 = create_occurrence(:url => 'http://example.com/?show=three')
    UberException.occurred(occurrence1)
    UberException.occurred(occurrence2)
    UberException.occurred(occurrence3)

    visit "/exceptions/#{occurrence1.uber_key}"
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

  def test_be_able_to_close_an_exception
    skip "not working so far"
    UberException.occurred(create_occurrence(:action_name => 'show'))
    UberException.occurred(create_occurrence(:action_name => 'index'))

    visit '/projects/ExampleProject'
    assert_contain 'NameError in users#show'
    assert_contain 'NameError in users#index'

    click_link 'NameError in users#show'

    click_button 'Close'
    # redirects back to project page
    assert_equal '/projects/ExampleProject', URI.parse(current_url).path
    assert_not_contain 'NameError in users#show'
    assert_contain 'NameError in users#index'
  end
end
