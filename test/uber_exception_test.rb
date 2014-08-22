require File.dirname(__FILE__) + '/test_helper'

class UberExceptionTest < Minitest::Test
  def setup
    clear_collections
  end

  def test_find_all_new_on_a_day
    project = Project.new('ExampleProject')

    old_ocr        = create_occurrence(:occurred_at => Time.local(2011, 8, 9, 14, 42))
    yesterday_ocr1 = create_occurrence(:action_name => 'index', :occurred_at => Time.local(2011, 8, 12, 14, 42))
    yesterday_ocr2 = create_occurrence(:action_name => 'index', :occurred_at => Time.local(2011, 8, 12, 15, 42))
    today_ocr      = create_occurrence(:action_name => 'create', :occurred_at => Time.local(2011, 8, 13, 14, 42))

    UberException.occurred(old_ocr)
    UberException.occurred(yesterday_ocr1)
    UberException.occurred(yesterday_ocr2)
    UberException.occurred(today_ocr)

    exceptions = UberException.find_new_on(project.name, Time.local(2011, 8, 12))
    assert_equal 1, exceptions.size
    assert_equal [yesterday_ocr1.uber_exception], exceptions
  end

  def test_forget_old_exceptions
    project = Project.new('ExampleProject')
    very_old_date = Time.now - (86400 * 50)

    very_old_exc = UberException.occurred(create_occurrence(:occurred_at => very_old_date))
    old_exc      = UberException.occurred(create_occurrence(:action_name => 'index', :occurred_at => Time.now - (86400 * 28)))
    today_exc    = UberException.occurred(create_occurrence(:action_name => 'create', :occurred_at => Time.now))

    assert_equal [today_exc, old_exc, very_old_exc], UberException.find_all_sorted_by_time(project.name, 0, 20)
    assert_equal [very_old_exc], UberException.find_new_on(project.name, very_old_date - 60)

    # shouldn't forget anything
    UberException.forget_old_exceptions(project.name, 51)

    assert_equal [today_exc, old_exc, very_old_exc], UberException.find_all_sorted_by_time(project.name, 0, 20)
    assert_equal [very_old_exc], UberException.find_new_on(project.name, very_old_date - 60)

    # should forget the very_old exception
    UberException.forget_old_exceptions(project.name, 30)

    assert_equal [today_exc, old_exc], UberException.find_all_sorted_by_time(project.name, 0, 20)
    assert_equal [], UberException.find_new_on(project.name, very_old_date - 60)

    # should forget even more
    UberException.forget_old_exceptions(project.name, 1)

    assert_equal [today_exc], UberException.find_all_sorted_by_time(project.name, 0, 20)
    assert_equal [], UberException.find_new_on(project.name, Time.now - 86400 - 3600)
  end
end
