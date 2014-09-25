require 'test_helper'

class HelperTest < MiniTest::Test

  def setup
    Timecop.freeze(Time.local(2010, 5, 5))
  end

  def teardown
    Timecop.return
  end

  def test_get_day_ago
    assert_equal Time.local(2010, 5, 5), Helper.get_day_ago(1)
    assert_equal Time.local(2010, 5, 1), Helper.get_day_ago(5)
  end

  def test_last_n_days
    assert_equal 2, Helper.last_n_days(2).size
    assert_equal 4, Helper.last_n_days(4).size
  end

  def test_wrap
    assert_equal [1], Helper.wrap(1)
    assert_equal [], Helper.wrap(nil)
    assert_equal [1], Helper.wrap([1])
    assert_equal [{test: 1}, {test: 2}], Helper.wrap([{test: 1}, {test: 2}])
    assert_equal [{test: 1}], Helper.wrap({test: 1})
  end
  
  def test_day_range
    expect = { gte: Helper.es_time(Time.local(2010, 5, 5)), lte: Helper.es_time(Time.local(2010, 5, 5, 23, 59, 59)) }
    assert_equal expect, Helper.day_range(Time.local(2010, 5, 5, 12, 30, 10))
  end
end
