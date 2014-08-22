require File.dirname(__FILE__) + '/test_helper'

class OccurrenceTest < Minitest::Test

  def setup
    clear_collections
  end

  def test_parse_a_exception
    hash = Occurrence.parse_xml(read_fixtures_file('fixtures/exception.xml'))

    assert_equal 'http://example.com', hash[:url]
    assert_equal 'users', hash[:controller_name]
    assert_equal nil, hash[:action_name]
    assert_equal 'RuntimeError', hash[:exception_class]
    assert_equal 'RuntimeError: I have made a huge mistake', hash[:exception_message]
    assert_equal ["[PROJECT_ROOT]/app/models/user.rb:53:in `public'",
                  "[PROJECT_ROOT]/app/controllers/users_controller.rb:14:in `index'"], hash[:exception_backtrace]
    assert_equal 'production', hash[:environment]
    assert_equal 'SECRET_API_KEY', hash[:api_key]

    assert_equal({ "SERVER_NAME"=>"example.org", "HTTP_USER_AGENT"=>"Mozilla" }, hash[:cgi_data])
    assert_equal({}, hash[:session])
    assert_equal({}, hash[:parameters])
  end

  def test_parse_a_minimal_exception
    Occurrence.parse_xml(read_fixtures_file('fixtures/minimal_exception.xml'))
  end

  def test_parse_a_full_exception
    Occurrence.parse_xml(read_fixtures_file('fixtures/full_exception.xml'))
  end

  def test_create_a_model_from_xml
    occurrence = Occurrence.from_xml(read_fixtures_file('fixtures/exception.xml'))

    assert_nil occurrence.project_name

    assert_equal 'http://example.com', occurrence.url
    assert_equal 'users', occurrence.controller_name
    assert_equal nil, occurrence.action_name
    assert_equal 'RuntimeError', occurrence.exception_class
    assert_equal 'RuntimeError: I have made a huge mistake', occurrence.exception_message
    assert_equal ["[PROJECT_ROOT]/app/models/user.rb:53:in `public'",
                  "[PROJECT_ROOT]/app/controllers/users_controller.rb:14:in `index'"], occurrence.exception_backtrace
    assert_equal 'production', occurrence.environment
    assert_equal 'SECRET_API_KEY', occurrence.api_key

    assert_equal({ "SERVER_NAME"=>"example.org", "HTTP_USER_AGENT"=>"Mozilla" }, occurrence.cgi_data)
    assert_equal({}, occurrence.session)
    assert_equal({}, occurrence.parameters)

    refute_nil occurrence.occurred_at
    refute_nil occurrence.uber_key
  end

  def test_parse_an_exception_with_hash_in_params
    occurrence = Occurrence.from_xml(read_fixtures_file('fixtures/exception_with_hash_in_params.xml'))

    hash_in_params = { "parent" => { "key_1" => "value_1",
                                     "key_2" => "value_2",
                                     "key_3" => { "key_4" => "value_3" } } }

    assert_equal(hash_in_params, occurrence.parameters)
  end

  def test_an_occurrence_occurred
    occurrence = create_occurrence
    UberException.occurred(occurrence)

    uber_exp = occurrence.uber_exception
    assert_equal 1, uber_exp.occurrences_count
    assert_equal 'NameError: undefined local variable or method dude', uber_exp.first_occurrence.exception_message
  end

  def test_generate_uber_key
    base_key = build_occurrence.uber_key
    assert_equal base_key, build_occurrence(:url => 'lala.com').uber_key
    assert_equal base_key, build_occurrence(:session => {:user_id => 17}).uber_key

    refute_equal base_key, build_occurrence(:exception_class => 'NoMethodError').uber_key
  end

  def test_generate_uber_key_for_occurrences_in_different_projects
    project1_key = build_occurrence(:project_name => 'project1').uber_key
    project2_key = build_occurrence(:project_name => 'project2').uber_key

    refute_equal project1_key, project2_key
  end

  def test_generate_uber_key_for_the_same_NoMethodError
    key1 = build_occurrence(:exception_class => 'NoMethodError',
      :exception_message => "NoMethodError: undefined method `service' for #<Post:0x14490624>").uber_key
    key2 = build_occurrence(:exception_class => 'NoMethodError',
      :exception_message => "NoMethodError: undefined method `service' for #<Post:0x176841f8>").uber_key

    assert_equal key1, key2
  end

  def test_generate_different_uber_keys_for_different_NoMethodErrors
    key1 = build_occurrence(:exception_class => 'NoMethodError',
      :exception_message => "NoMethodError: undefined method `service' for #<Post:0x14490624>",
      :exception_backtrace => ["[GEM_ROOT]/gems/activerecord-2.3.4/lib/active_record/attribute_methods.rb:260:in `method_missing'"]).uber_key
    key2 = build_occurrence(:exception_class => 'NoMethodError',
      :exception_message => "NoMethodError: undefined method `name' for nil:NilClass",
      :exception_backtrace => ["[PROJECT_ROOT]/app/models/post.rb:184:in `name'"]).uber_key

    refute_equal key1, key2
  end

  def test_aggregate_RuntimeErrors
    runtime_exception = { :exception_class => 'RuntimeError' }

    base_key = build_occurrence(runtime_exception).uber_key
    assert_equal base_key, build_occurrence(runtime_exception.merge(:controller_name => 'projects')).uber_key
    assert_equal base_key, build_occurrence(runtime_exception.merge(:action_name => 'index')).uber_key
  end

  def test_aggregate_TimeoutErrors
    timeout_backtrace = [
      "/opt/ruby-enterprise/lib/ruby/1.8/net/protocol.rb:135:in `call'",
      "[PROJECT_ROOT]/vendor/plugins/acts_as_solr/lib/solr/connection.rb:158:in `post'"
    ]
    timeout_exception = { :exception_class => 'Timeout::Error', :exception_backtrace => timeout_backtrace }

    base_key = build_occurrence(timeout_exception).uber_key
    assert_equal base_key, build_occurrence(timeout_exception.merge(:controller_name => 'projects')).uber_key
    assert_equal base_key, build_occurrence(timeout_exception.merge(:action_name => 'index')).uber_key

    timeout_backtrace.insert(0, "/opt/ruby-enterprise/lib/ruby/gems/1.8/gems/system_timer-1.0/lib/system_timer.rb:42:in `install_ruby_sigalrm_handler'")
    assert_equal base_key, build_occurrence(timeout_exception.merge(:exception_backtrace => timeout_backtrace)).uber_key

    timeout_backtrace[2] = "[PROJECT_ROOT]/app/models/user.rb:158:in `post'"
    refute_equal base_key, build_occurrence(timeout_exception.merge(:exception_backtrace => timeout_backtrace)).uber_key
  end
end
