require 'test_helper'

class UberExceptionTest < AbstractTest

  def test_count_all
    UberException.occurred(create_occurrence())

    Exceptionist.esclient.refresh

    assert_equal 1, UberException.count_all('ExampleProject')

    UberException.occurred(create_occurrence(action_name: 'other'))
    UberException.occurred(create_occurrence(project_name: 'OtherProject'))

    Exceptionist.esclient.refresh

    assert_equal 2, UberException.count_all('ExampleProject')
  end

  def test_get
    uber_exception = UberException.occurred(create_occurrence())

    Exceptionist.esclient.refresh

    assert_equal uber_exception.id, UberException.get(uber_exception.id).id
  end

  def test_find
    exce1 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 12, 14, 42), action_name: 'action1'))
    exce2 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 12, 15, 42), action_name: 'action2'))
    exce3 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 13, 14, 42), action_name: 'action3'))
    exce4 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 14, 14, 42), action_name: 'action4'))

    Exceptionist.esclient.refresh

    assert_equal [exce4, exce3, exce2, exce1], UberException.find(project: 'ExampleProject')
    assert_equal [exce2], UberException.find(project: 'ExampleProject', from: 2, size: 1)
  end

  def test_update_last_occurred_at
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 12)))

    Exceptionist.esclient.refresh

    assert_equal Time.local(2011, 8, 12), UberException.find(project: 'ExampleProject').first.last_occurred_at

    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 13)))

    Exceptionist.esclient.refresh

    assert_equal Time.local(2011, 8, 13), UberException.find(project: 'ExampleProject').first.last_occurred_at
  end

  def test_find_sorted_by_occurrences_count
    exce1 = UberException.occurred(create_occurrence())
    UberException.occurred(create_occurrence())
    UberException.occurred(create_occurrence())
    exce3 = UberException.occurred(create_occurrence(action_name: 'different'))
    exce2 = UberException.occurred(create_occurrence(action_name: 'other'))
    UberException.occurred(create_occurrence(action_name: 'other'))


    Exceptionist.esclient.refresh

    assert_equal [exce1, exce2, exce3], UberException.find_sorted_by_occurrences_count('ExampleProject', 0, 10)
    assert_equal [exce2, exce3], UberException.find_sorted_by_occurrences_count('ExampleProject', 1, 10)
  end

  def test_find_since_last_deploy
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 12), action_name: 'action1'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 14), action_name: 'action2'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 15), action_name: 'action2'))
    exce2 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 15), action_name: 'action2'))
    exce3 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 16), action_name: 'action3'))

    create_deploy(deploy_time: Time.local(2011, 8, 13))

    Exceptionist.esclient.refresh

    assert_equal [exce3, exce2], UberException.find_since_last_deploy('ExampleProject')

    UberException.occurred(create_occurrence(occurred_at: Time.local(2010, 8, 11), action_name: 'action4'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2010, 8, 12), action_name: 'action4'))
    exce4 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 17), action_name: 'action4'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 18), action_name: 'action2'))

    Exceptionist.esclient.refresh

    assert_equal [exce2, exce4, exce3], UberException.find_since_last_deploy('ExampleProject')
  end

  def test_find_new_on
    project = Project.new('ExampleProject')

    old_occur        = create_occurrence(occurred_at: Time.local(2011, 8, 9, 14, 42))
    yesterday_occur1 = create_occurrence(action_name: 'index', occurred_at: Time.local(2011, 8, 12, 14, 42))
    yesterday_occur2 = create_occurrence(action_name: 'index', occurred_at: Time.local(2011, 8, 12, 15, 42))
    today_occur1     = create_occurrence(action_name: 'create', occurred_at: Time.local(2011, 8, 13, 14, 42))
    today_occur2     = create_occurrence(action_name: 'index', occurred_at: Time.local(2011, 8, 13, 14, 42))

    UberException.occurred(old_occur)
    UberException.occurred(yesterday_occur1)
    UberException.occurred(yesterday_occur2)
    UberException.occurred(today_occur1)
    UberException.occurred(today_occur2)

    Exceptionist.esclient.refresh

    exceptions = UberException.find_new_on(project.name, Time.local(2011, 8, 12))
    assert_equal 1, exceptions.size
    assert_equal [yesterday_occur1.uber_exception], exceptions
  end

  def test_forget_old_exceptions
    project = Project.new('ExampleProject')
    very_old_date = Time.now - (86400 * 50)

    very_old_exec = UberException.occurred(create_occurrence(occurred_at: very_old_date))
    old_exec      = UberException.occurred(create_occurrence(action_name: 'index', occurred_at: Time.now - (86400 * 28)))
    today_exec    = UberException.occurred(create_occurrence(action_name: 'create', occurred_at: Time.now))

    Exceptionist.esclient.refresh

    assert_equal [today_exec, old_exec, very_old_exec], UberException.find(project: project.name)
    assert_equal [very_old_exec], UberException.find_new_on(project.name, very_old_date - 60)

    # shouldn't forget anything
    UberException.forget_old_exceptions(project.name, 51)

    Exceptionist.esclient.refresh

    assert_equal [today_exec, old_exec, very_old_exec], UberException.find(project: project.name)
    assert_equal [very_old_exec], UberException.find_new_on(project.name, very_old_date - 60)

    # should forget the very_old exception
    UberException.forget_old_exceptions(project.name, 30)

    Exceptionist.esclient.refresh

    assert_equal [today_exec, old_exec], UberException.find(project: project.name)
    assert_equal [], UberException.find_new_on(project.name, very_old_date - 60)

    # should forget even more
    UberException.forget_old_exceptions(project.name, 1)

    Exceptionist.esclient.refresh

    assert_equal [today_exec], UberException.find(project: project.name)
    assert_equal [], UberException.find_new_on(project.name, Time.now - 86400 - 3600)
  end

  def test_forget!
    uber_exce = UberException.occurred(create_occurrence())
    uber_exce.forget!

    Exceptionist.esclient.refresh

    assert_raises(Elasticsearch::Transport::Transport::Errors::NotFound) do
      UberException.get(uber_exce.id)
    end
  end

  def test_close!
    uber_exce = UberException.occurred(create_occurrence())
    uber_exce.close!

    Exceptionist.esclient.refresh

    assert_equal [], UberException.find(project: 'ExampleProject')
  end

  def test_current_occurrence
    ocr1 = create_occurrence(occurred_at: Time.local(2011, 8, 12, 15, 42))
    ocr2 = create_occurrence(occurred_at: Time.local(2011, 8, 13, 14, 42))
    uber_ex = UberException.occurred(ocr1)
    UberException.occurred(ocr2)

    Exceptionist.esclient.refresh

    assert_equal ocr1, uber_ex.current_occurrence(1)
    assert_equal ocr2, uber_ex.current_occurrence(2)

    assert_equal nil, uber_ex.current_occurrence(3)

    assert_raises ArgumentError do
      uber_ex.current_occurrence(0)
    end
  end

  def test_update_occurence_count
    uber_ex = UberException.occurred(create_occurrence())
    UberException.occurred(create_occurrence())

    Exceptionist.esclient.refresh

    Exceptionist.esclient.update('exceptions', uber_ex.id, { doc: { occurrences_count: 42 } })

    Exceptionist.esclient.refresh

    assert_equal 42, Exceptionist.esclient.get_exception(uber_ex.id).occurrences_count

    uber_ex.update_occurrences_count

    Exceptionist.esclient.refresh

    assert_equal 2, Exceptionist.esclient.get_exception(uber_ex.id).occurrences_count
  end

  def test_occurrences_count_on
    uber_ex = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 12, 14, 42)))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 12, 15, 42)))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 8, 13, 14, 42)))

    Exceptionist.esclient.refresh

    assert_equal 2, uber_ex.occurrences_count_on(Time.local(2011, 8, 12))
    assert_equal 1, uber_ex.occurrences_count_on(Time.local(2011, 8, 13))
  end
end
