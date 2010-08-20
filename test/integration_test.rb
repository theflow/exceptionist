require File.dirname(__FILE__) + '/test_helper'

require 'rack/test'
require 'webrat'

Webrat.configure do |config|
  config.mode = :rack
end

context 'IntegrationTest' do
  include Rack::Test::Methods
  include Webrat::Methods
  include Webrat::Matchers

  def app
    ExceptionistApp
  end

  setup do
    Exceptionist.redis.flushall
  end

  context 'the Dashboard' do
    test 'should show a empty dashboard' do
      visit '/'
    end

    test 'should show the dashboard with one project' do
      occurrence = create_occurrence
      UberException.occurred(occurrence)

      visit '/'
      assert_contain 'ExampleProject'

      click_link 'ExampleProject'
    end

    test 'should show the dashboard with two projects' do
      occurrence1 = create_occurrence(:project_name => 'Project1')
      UberException.occurred(occurrence1)

      occurrence2 = create_occurrence(:project_name => 'Project2')
      UberException.occurred(occurrence2)

      visit '/'
      assert_contain 'Project1'
      assert_contain 'Project2'
    end
  end

  context 'the exception list' do
    test 'with one exception' do
      occurrence = create_occurrence
      UberException.occurred(occurrence)
      UberException.occurred(occurrence)

      visit '/projects/ExampleProject'

      assert_contain 'Latest Exceptions for ExampleProject'
      assert_contain 'NameError in users#show'
      assert_contain '# 2'
    end

    test 'with pagination' do
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

    test 'should be filtered by most recent' do
      UberException.occurred(create_occurrence(:action_name => 'show', :occurred_at => '2010-03-01'))
      UberException.occurred(create_occurrence(:action_name => 'index', :occurred_at => '2009-02-01'))

      visit '/projects/ExampleProject'

      # TODO: how to test order?
      assert_contain 'NameError in users#index'
      assert_contain 'NameError in users#show'
    end

    test 'should email new exceptions' do
      UberException.occurred(create_occurrence(:action_name => 'show', :occurred_at => '2010-07-01'))
      UberException.occurred(create_occurrence(:action_name => 'index', :occurred_at => '2010-08-01'))

      visit '/projects/ExampleProject/new_on/2010-07-01?mail_to=the@dude.org'

      assert_contain 'NameError in users#show'
      assert_not_contain 'NameError in users#index'
    end
  end

  context 'a single exception' do
    test 'should show a minimal occurrence' do
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

    test 'should paginate occurrences' do
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

    test 'should be able to close an exception' do
      UberException.occurred(create_occurrence(:action_name => 'show'))
      UberException.occurred(create_occurrence(:action_name => 'index'))

      visit '/projects/ExampleProject'
      assert_contain 'NameError in users#show'
      assert_contain 'NameError in users#index'

      click_link 'NameError in users#show'

      click_button 'Close'
      # redirects back to project page
      assert_equal '/projects/ExampleProject?', current_url
      assert_not_contain 'NameError in users#show'
      assert_contain 'NameError in users#index'
    end
  end
end
