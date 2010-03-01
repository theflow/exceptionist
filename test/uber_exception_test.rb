require File.dirname(__FILE__) + '/test_helper'

context 'Finding UberExceptions' do
  setup do
    Exceptionist.redis.flush_all
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
end
