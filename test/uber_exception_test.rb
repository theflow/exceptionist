require File.dirname(__FILE__) + '/test_helper'

context 'UberExceptionTest' do
  setup do
    Exceptionist.redis.flushall
  end

  test 'should find all occurrences since' do
    project = Project.new('ExampleProject')

    old_ocr        = create_occurrence(:occurred_at => Time.now - (84600 * 4))
    yesterday_ocr1 = create_occurrence(:action_name => 'index', :occurred_at => Time.now - (84600 * 1))
    yesterday_ocr2 = create_occurrence(:action_name => 'index', :occurred_at => Time.now - (84600 * 1))
    today_ocr      = create_occurrence(:action_name => 'create', :occurred_at => Time.now)

    UberException.occurred(old_ocr)
    UberException.occurred(yesterday_ocr1)
    UberException.occurred(yesterday_ocr2)
    UberException.occurred(today_ocr)

    exceptions = UberException.find_new_on(project.name, Time.now - (84600 * 2))
    assert_equal 1, exceptions.size
    assert_equal [yesterday_ocr1.uber_exception], exceptions
  end

  test 'should forget old exceptions' do
    project = Project.new('ExampleProject')
    very_old_date = Time.now - (84600 * 50)

    very_old_exc = UberException.occurred(create_occurrence(:occurred_at => very_old_date))
    old_exc      = UberException.occurred(create_occurrence(:action_name => 'index', :occurred_at => Time.now - (84600 * 28)))
    today_exc    = UberException.occurred(create_occurrence(:action_name => 'create', :occurred_at => Time.now))

    assert_equal [today_exc, old_exc, very_old_exc], UberException.find_all_sorted_by_time(project.name, nil, 0, 20)
    assert_equal [very_old_exc], UberException.find_new_on(project.name, very_old_date - 60)

    # shouldn't forget anything
    UberException.forget_old_exceptions(project.name, 51)

    assert_equal [today_exc, old_exc, very_old_exc], UberException.find_all_sorted_by_time(project.name, nil, 0, 20)
    assert_equal [very_old_exc], UberException.find_new_on(project.name, very_old_date - 60)

    # should forget the very_old exception
    UberException.forget_old_exceptions(project.name, 30)

    assert_equal [today_exc, old_exc], UberException.find_all_sorted_by_time(project.name, nil, 0, 20)
    assert_equal [], UberException.find_new_on(project.name, very_old_date - 60)

    # should forget even more
    UberException.forget_old_exceptions(project.name, 1)

    assert_equal [today_exc], UberException.find_all_sorted_by_time(project.name, nil, 0, 20)
    assert_equal [], UberException.find_new_on(project.name, Time.now - 84600 - 3600)
  end
end
