require File.dirname(__FILE__) + '/test_helper'

context 'Parse Hoptoad XML' do
  test 'should parse a exception' do
    hash = Occurrence.parse_xml(read_fixtures_file('fixtures/exception.xml'))

    assert_equal 'http://example.com', hash[:url]
    assert_equal 'users', hash[:controller_name]
    assert_equal nil, hash[:action_name]
    assert_equal 'RuntimeError', hash[:exception_class]
    assert_equal 'RuntimeError: I have made a huge mistake', hash[:exception_message]
    assert_equal ["[PROJECT_ROOT]/app/models/user.rb:53:in `public'",
                  "[PROJECT_ROOT]/app/controllers/users_controller.rb:14:in `index'"], hash[:exception_backtrace]
    assert_equal 'production', hash[:environment]
    assert_equal 'ExampleProject', hash[:project_name]

    assert_equal({ "SERVER_NAME"=>"example.org", "HTTP_USER_AGENT"=>"Mozilla" }, hash[:cgi_data])
    assert_equal({}, hash[:session])
    assert_equal({}, hash[:parameters])
  end

  test 'should parse a minimal exception' do
    assert_nothing_raised do
      Occurrence.parse_xml(read_fixtures_file('fixtures/minimal_exception.xml'))
    end
  end

  test 'should parse a full exception' do
    assert_nothing_raised do
      Occurrence.parse_xml(read_fixtures_file('fixtures/full_exception.xml'))
    end
  end

  test 'should create a model from xml' do
    occurrence = Occurrence.from_xml(read_fixtures_file('fixtures/exception.xml'))

    assert_equal 'http://example.com', occurrence.url
    assert_equal 'users', occurrence.controller_name
    assert_equal nil, occurrence.action_name
    assert_equal 'RuntimeError', occurrence.exception_class
    assert_equal 'RuntimeError: I have made a huge mistake', occurrence.exception_message
    assert_equal ["[PROJECT_ROOT]/app/models/user.rb:53:in `public'",
                  "[PROJECT_ROOT]/app/controllers/users_controller.rb:14:in `index'"], occurrence.exception_backtrace
    assert_equal 'production', occurrence.environment
    assert_equal 'ExampleProject', occurrence.project_name

    assert_equal({ "SERVER_NAME"=>"example.org", "HTTP_USER_AGENT"=>"Mozilla" }, occurrence.cgi_data)
    assert_equal({}, occurrence.session)
    assert_equal({}, occurrence.parameters)

    assert_not_nil occurrence.occurred_at
    assert_not_nil occurrence.uber_key
  end
end

OCCURRENCE = { :exception_class     => 'NameError',
               :exception_message   => 'NameError: undefined local variable or method dude',
               :exception_backtrace => ["[PROJECT_ROOT]/app/models/user.rb:53:in `public'", "[PROJECT_ROOT]/app/controllers/users_controller.rb:14:in `show'"],
               :controller_name     => 'users',
               :action_name         => 'show',
               :project_name        => 'ExampleProject',
               :url                 => 'http://example.com' }

context 'Occurrence saving' do
  setup do
    Exceptionist.redis.flush_all
  end

  test 'saving an occurrence should set the ID' do
    occurrence = Occurrence.new
    assert_nil occurrence.id

    occurrence.save

    assert_not_nil occurrence.id
  end

  test 'an occurrence occurred' do
    occurrence = Occurrence.new(OCCURRENCE).save
    UberException.occurred(occurrence)

    uber_exp = UberException.new(occurrence.uber_key)
    assert_equal 1, uber_exp.occurrences_count
    assert_equal 'NameError: undefined local variable or method dude', uber_exp.first_occurrence.exception_message
  end

  test 'an occurrence occurred and should be filtered' do
    Exceptionist.filter.add :dotcom do |occurrence|
      occurrence.url =~ /\.com/
    end

    occurrence1 = Occurrence.new(OCCURRENCE).save
    UberException.occurred(occurrence1)
    occurrence2 = Occurrence.new(OCCURRENCE.merge(:exception_class => 'DifferentError', :url => 'http://example.org')).save
    UberException.occurred(occurrence2)

    filtered_exceptions = UberException.find_all_sorted_by_time('ExampleProject', :dotcom, 0, 25)
    assert_equal 1, filtered_exceptions.size
    assert_equal occurrence1.uber_key, filtered_exceptions.first.id

    all_exceptions = UberException.find_all_sorted_by_time('ExampleProject', nil, 0, 25)
    assert_equal 2, all_exceptions.size
    assert_equal [occurrence2.uber_key, occurrence1.uber_key], all_exceptions.map(&:id)
  end
end

context 'Occurrence aggregation' do
  test 'should generate uber key' do
    assert_equal '0e783598eacef69332e0ea5cb3c38ea52bf3b3b1', Occurrence.new(OCCURRENCE).uber_key
    assert_equal '0e783598eacef69332e0ea5cb3c38ea52bf3b3b1', Occurrence.new(OCCURRENCE.merge(:url => 'lala.com')).uber_key
    assert_equal '0e783598eacef69332e0ea5cb3c38ea52bf3b3b1', Occurrence.new(OCCURRENCE.merge(:session => {:user_id => 17})).uber_key

    assert_not_equal '0e783598eacef69332e0ea5cb3c38ea52bf3b3b1', Occurrence.new(OCCURRENCE.merge(:exception_class => 'NoMethodError')).uber_key
  end

  test 'should aggregate RuntimeErrors' do
    runtime_exception = OCCURRENCE.merge(:exception_class => 'RuntimeError')

    base_key = Occurrence.new(runtime_exception).uber_key
    assert_equal base_key, Occurrence.new(runtime_exception.merge(:controller_name => 'projects')).uber_key
    assert_equal base_key, Occurrence.new(runtime_exception.merge(:action_name => 'index')).uber_key
  end

  test 'should aggregate TimeoutErrors' do
    timeout_backtrace = [
      "/opt/ruby-enterprise/lib/ruby/1.8/net/protocol.rb:135:in `call'",
      "[PROJECT_ROOT]/vendor/plugins/acts_as_solr/lib/solr/connection.rb:158:in `post'"
    ]
    timeout_exception = OCCURRENCE.merge(:exception_class => 'Timeout::Error', :exception_backtrace => timeout_backtrace)

    base_key = Occurrence.new(timeout_exception).uber_key
    assert_equal base_key, Occurrence.new(timeout_exception.merge(:controller_name => 'projects')).uber_key
    assert_equal base_key, Occurrence.new(timeout_exception.merge(:action_name => 'index')).uber_key

    timeout_backtrace.insert(0, "/opt/ruby-enterprise/lib/ruby/gems/1.8/gems/system_timer-1.0/lib/system_timer.rb:42:in `install_ruby_sigalrm_handler'")
    assert_equal base_key, Occurrence.new(timeout_exception.merge(:exception_backtrace => timeout_backtrace)).uber_key

    timeout_backtrace[2] = "[PROJECT_ROOT]/app/models/user.rb:158:in `post'"
    assert_not_equal base_key, Occurrence.new(timeout_exception.merge(:exception_backtrace => timeout_backtrace)).uber_key
  end
end
