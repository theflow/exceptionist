require File.dirname(__FILE__) + '/test_helper'

OCCURRENCE = { :exception_class     => 'NameError',
               :exception_message   => 'NameError: undefined local variable or method dude',
               :exception_backtrace => ["[PROJECT_ROOT]/app/models/user.rb:53:in `public'", "[PROJECT_ROOT]/app/controllers/users_controller.rb:14:in `show'"],
               :controller_name     => 'users',
               :action_name         => 'show',
               :project_name        => 'ExampleProject',
               :url                 => 'http://example.com' }

context 'Finding UberExceptions' do
  setup do
    Exceptionist.redis.flush_all
  end

  test 'should find all occurrences since' do
    project = Project.new('ExampleProject')

    old_ocr       = Occurrence.create(OCCURRENCE.merge(:occurred_at => Time.now - (84600 * 4)))
    yesterday_ocr = Occurrence.create(OCCURRENCE.merge(:action_name => 'index', :occurred_at => Time.now - (84600 * 1)))
    today_ocr     = Occurrence.create(OCCURRENCE.merge(:action_name => 'create', :occurred_at => Time.now))

    UberException.occurred(old_ocr)
    UberException.occurred(yesterday_ocr)
    UberException.occurred(today_ocr)

    exceptions = UberException.find_new_since(project.name, Time.now - (84600 * 2))
    assert_equal 2, exceptions.size
    assert_equal [yesterday_ocr.uber_exception, today_ocr.uber_exception], exceptions
  end
end
