require 'test_helper'

class UberExceptionTest < MiniTest::Test

  def setup
    clear_collections

    @occur1 = create_occurrence(occurred_at: Time.local(2011, 1, 1))
    @occur2 = create_occurrence(occurred_at: Time.local(2011, 1, 2))
    UberException.occurred(@occur1)
    UberException.occurred(@occur2)
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 3)))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 4)))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 5)))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 6)))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 7)))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 8)))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 9)))
    @exce1 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 10)))

    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 4), action_name: 'save'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'save'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'save'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'save'))
    @exce2 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'save'))

    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 2), action_name: 'delete'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 4), action_name: 'delete'))
    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 6), action_name: 'delete'))
    @exce3 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 8), action_name: 'delete'))

    @exce4 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 5), action_name: 'otherAction'))

    UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 4), project_name: 'OtherProject'))
    @exce5 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 8), project_name: 'OtherProject'))

    @exce6 = UberException.occurred(create_occurrence(occurred_at: Time.local(2011, 1, 8), project_name: 'ThirdProject'))

    create_deploy(occurred_at: Time.local(2011, 1, 5, 12, 0))

    create_deploy(occurred_at: Time.local(2011, 1, 6), project_name: 'OtherProject')

    create_deploy(occurred_at: Time.local(2011, 1, 6), project_name: 'ThirdProject')

    Exceptionist.esclient.refresh
  end

  def test_occurred
    assert_equal Time.local(2011, 1, 1), @exce1.first_occurred_at
    assert_equal Time.local(2011, 1, 10), @exce1.last_occurrence.occurred_at
  end

  def test_count_all
    assert_equal 4, UberException.count_all('ExampleProject')
    assert_equal 1, UberException.count_all('OtherProject')
  end

  def test_count_since
    assert_equal 4, UberException.count_since(project: 'ExampleProject', date: Time.local(2011, 1, 1))
    assert_equal 2, UberException.count_since(project: 'ExampleProject', date: Time.local(2011, 1, 7))
    assert_equal 1, UberException.count_since(project: 'ExampleProject', date: Time.local(2011, 1, 9))
  end

  def test_get
    assert_equal @exce1.id, UberException.get(@exce1.id).id
  end

  def test_find
    assert_equal [@exce1, @exce3, @exce2, @exce4], UberException.find(project: 'ExampleProject')
    assert_equal [@exce2], UberException.find(project: 'ExampleProject', from: 2, size: 1)
  end

  def test_find_sorted_by_occurrences_count
    assert_equal [@exce1, @exce2, @exce3, @exce4], UberException.find_sorted_by_occurrences_count(project: 'ExampleProject')
  end

  def test_find_since_last_deploy

    uber_exces = UberException.find_since_last_deploy(project: 'ExampleProject')

    assert_equal [@exce1, @exce3,  @exce2], uber_exces
    assert_equal 5, uber_exces[0].occurrences_count
    assert_equal Time.local(2011, 1, 1), uber_exces[0].first_occurred_at
    assert_equal 2, uber_exces[1].occurrences_count
    assert_equal Time.local(2011, 1, 2), uber_exces[1].first_occurred_at
    assert_equal 4, uber_exces[2].occurrences_count
    assert_equal Time.local(2011, 1, 4), uber_exces[2].first_occurred_at

    uber_exces = UberException.find_since_last_deploy(project: 'OtherProject')

    assert_equal [@exce5], uber_exces
    assert_equal 1, uber_exces[0].occurrences_count
    assert_equal Time.local(2011, 1, 4), uber_exces[0].first_occurred_at
  end

  def test_find_since_last_deploy_with_no_deploy
    assert_equal nil, UberException.find_since_last_deploy(project: 'NotExistingProject')
  end

  def test_find_since_last_deploy_ordered_by_occurrences_count
    uber_exces = UberException.find_since_last_deploy_ordered_by_occurrences_count(project: 'ExampleProject')


    assert_equal [@exce1, @exce2, @exce3], uber_exces
    assert_equal 5, uber_exces[0].occurrences_count
    assert_equal Time.local(2011, 1, 1), uber_exces[0].first_occurred_at
    assert_equal 4, uber_exces[1].occurrences_count
    assert_equal Time.local(2011, 1, 4), uber_exces[1].first_occurred_at
    assert_equal 2, uber_exces[2].occurrences_count
    assert_equal Time.local(2011, 1, 2), uber_exces[2].first_occurred_at
  end

  def test_find_new_on
    exceptions = UberException.find_new_on('ExampleProject', Time.local(2011, 1, 1))
    assert_equal 1, exceptions.size

    assert_equal [], UberException.find_new_on('OtherProject', Time.local(2011, 1, 4, 12, 30))
  end

  def test_forget_old_exceptions
    days = (Time.now - Time.local(2011, 1, 1)) / 86400
    # shouldn't forget anything
    UberException.forget_old_exceptions('ExampleProject', days)
    Exceptionist.esclient.refresh

    assert_equal [@exce1, @exce3, @exce2, @exce4], UberException.find(project: 'ExampleProject')

    days = (Time.now - Time.local(2011, 1, 7)) / 86400
    UberException.forget_old_exceptions('ExampleProject', days)
    Exceptionist.esclient.refresh

    assert_equal [@exce1, @exce3], UberException.find(project: 'ExampleProject')

    UberException.forget_old_exceptions('ExampleProject')
    Exceptionist.esclient.refresh

    assert_equal [], UberException.find(project: 'ExampleProject')
  end

  def test_forget!
    @exce1.forget!
    Exceptionist.esclient.refresh

    assert_raises(Elasticsearch::Transport::Transport::Errors::NotFound) do
      UberException.get(@exce1.id)
    end
  end

  def test_close!
    @exce1.close!

    Exceptionist.esclient.refresh

    assert_equal [], UberException.find(filters: {term: { id: @exce1.id } } )
  end

  def test_current_occurrence
    assert_equal @occur1, @exce1.current_occurrence(1)
    assert_equal @occur2, @exce1.current_occurrence(2)

    assert_equal nil, @exce1.current_occurrence(11)

    assert_raises ArgumentError do
      @exce1.current_occurrence(0)
    end
  end

  def test_occurrences_count_on
    assert_equal 1, @exce1.occurrences_count_on(Time.local(2011, 1, 9))
    assert_equal 3, @exce2.occurrences_count_on(Time.local(2011, 1, 4))
  end

  def test_new_since
    assert ! @exce1.new_since_last_deploy
    assert ! @exce3.new_since_last_deploy
    assert @exce6.new_since_last_deploy
  end

  def test_update
    assert_equal nil, @exce1.category

    @exce1.update( { category: "low" } )
    Exceptionist.esclient.refresh

    assert_equal "low", UberException.get(@exce1.id).category
  end
end
