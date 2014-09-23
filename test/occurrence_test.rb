require 'test_helper'

class OccurrenceTest < MiniTest::Test

  def setup
    clear_collections

    @occur11 = create_occurrence(occurred_at: Time.local(2011, 1, 1))
    @occur12 = create_occurrence(occurred_at: Time.local(2011, 1, 2))
    create_occurrence(occurred_at: Time.local(2011, 1, 3))
    create_occurrence(occurred_at: Time.local(2011, 1, 4))
    create_occurrence(occurred_at: Time.local(2011, 1, 5))
    create_occurrence(occurred_at: Time.local(2011, 1, 6))
    create_occurrence(occurred_at: Time.local(2011, 1, 7))
    @occur18 = create_occurrence(occurred_at: Time.local(2011, 1, 8))
    @occur19 = create_occurrence(occurred_at: Time.local(2011, 1, 9))

    @occur21 = create_occurrence(occurred_at: Time.local(2011, 1, 4), action_name: 'save')
    create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'save')
    create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'save')
    create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'save')

    @occur31 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 5), action_name: 'otherAction'))

    @occur41 = create_occurrence(occurred_at: Time.local(2011, 1, 8), project_name: 'OtherProject', exception_class: 'Mysql::Error', exception_message: 'Line 42')

    Exceptionist.esclient.refresh
  end

  def test_get_uber_exce
    exce = UberException.occurred(@occur11)
    Exceptionist.esclient.refresh

    assert_equal exce, @occur11.uber_exception
  end

  def test_title_accessor
    assert_equal 'Mysql::Error Line 42', @occur41.title
  end

  def test_delete_all_for
    Occurrence.delete_all_for(@occur11.uber_key)
    Exceptionist.esclient.refresh

    assert_equal 5, Occurrence.find(filters: { term: { project_name: 'ExampleProject' } } ).size
    assert_equal 1, Occurrence.find(filters: { term: { project_name: 'OtherProject' } } ).size
  end

  def test_find_first_for
    assert_equal @occur11, Occurrence.find_first_for(@occur12.uber_key)
  end

  def test_find_last_for
    assert_equal @occur19, Occurrence.find_last_for(@occur12.uber_key)
  end

  def test_find_since
    assert_equal [@occur19, @occur18], Occurrence.find_since(uber_key: @occur18.uber_key, date: Time.local(2011, 1, 7, 12, 0))
  end

  def test_find_next
    assert_equal @occur19, Occurrence.find_next(@occur18.uber_key, Time.local(2011, 1, 8, 12, 0))
    assert_equal @occur12, Occurrence.find_next(@occur11.uber_key, Time.local(2011, 1, 1, 12, 0))
  end

  def test_count_all_on
    assert_equal 0, Occurrence.count_all_on('ExampleProject', Time.local(2011, 1, 20))
    assert_equal 4, Occurrence.count_all_on('ExampleProject', Time.local(2011, 1, 6))
  end

  def test_count_since
    assert_equal 2, Occurrence.count_since(@occur11.uber_key, Time.local(2011, 1, 7, 12, 0))
    assert_equal 0, Occurrence.count_since(@occur21.uber_key, Time.local(2011, 1, 8))
  end


  def test_find
    assert_equal 15, Occurrence.find.size
  end

  def test_generate_uber_key
    base_key = build_occurrence.uber_key
    assert_equal base_key, build_occurrence(url: 'lala.com').uber_key
    assert_equal base_key, build_occurrence(session: {user_id: 17}).uber_key

    refute_equal base_key, build_occurrence(exception_class: 'NoMethodError').uber_key
  end

  def test_generate_uber_key_for_occurrences_in_different_projects
    project1_key = build_occurrence(project_name: 'project1').uber_key
    project2_key = build_occurrence(project_name: 'project2').uber_key

    refute_equal project1_key, project2_key
  end

  def test_generate_uber_key_for_the_same_NoMethodError
    key1 = build_occurrence(exception_class: 'NoMethodError',
      exception_message: "NoMethodError: undefined method `service' for #<Post:0x14490624>").uber_key
    key2 = build_occurrence(exception_class: 'NoMethodError',
      exception_message: "NoMethodError: undefined method `service' for #<Post:0x176841f8>").uber_key

    assert_equal key1, key2
  end

  def test_generate_different_uber_keys_for_different_NoMethodErrors
    key1 = build_occurrence(exception_class: 'NoMethodError',
      exception_message: "NoMethodError: undefined method `service' for #<Post:0x14490624>",
      exception_backtrace: ["[GEM_ROOT]/gems/activerecord-2.3.4/lib/active_record/attribute_methods.rb:260:in `method_missing'"]).uber_key
    key2 = build_occurrence(exception_class: 'NoMethodError',
      exception_message: "NoMethodError: undefined method `name' for nil:NilClass",
      exception_backtrace: ["[PROJECT_ROOT]/app/models/post.rb:184:in `name'"]).uber_key

    refute_equal key1, key2
  end

  def test_aggregate_RuntimeErrors
    runtime_exception = { exception_class: 'RuntimeError' }

    base_key = build_occurrence(runtime_exception).uber_key
    assert_equal base_key, build_occurrence(runtime_exception.merge(controller_name: 'projects')).uber_key
    assert_equal base_key, build_occurrence(runtime_exception.merge(action_name: 'index')).uber_key
  end

  def test_aggregate_TimeoutErrors
    timeout_backtrace = [
      "/opt/ruby-enterprise/lib/ruby/1.8/net/protocol.rb:135:in `call'",
      "[PROJECT_ROOT]/vendor/plugins/acts_as_solr/lib/solr/connection.rb:158:in `post'"
    ]
    timeout_exception = { exception_class: 'Timeout::Error', exception_backtrace: timeout_backtrace }

    base_key = build_occurrence(timeout_exception).uber_key
    assert_equal base_key, build_occurrence(timeout_exception.merge(controller_name: 'projects')).uber_key
    assert_equal base_key, build_occurrence(timeout_exception.merge(action_name: 'index')).uber_key

    timeout_backtrace.insert(0, "/opt/ruby-enterprise/lib/ruby/gems/1.8/gems/system_timer-1.0/lib/system_timer.rb:42:in `install_ruby_sigalrm_handler'")
    assert_equal base_key, build_occurrence(timeout_exception.merge(exception_backtrace: timeout_backtrace)).uber_key

    timeout_backtrace[2] = "[PROJECT_ROOT]/app/models/user.rb:158:in `post'"
    refute_equal base_key, build_occurrence(timeout_exception.merge(exception_backtrace: timeout_backtrace)).uber_key
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

end
