require 'test_helper'

class HelpersTest < MiniTest::Test

  def setup
    Timecop.freeze(Time.local(2010, 5, 5))
  end

  def teardown
    Timecop.return
  end

  def test_get_day_ago
    assert_equal Time.local(2010, 5, 5), Helpers.get_day_ago(1)
    assert_equal Time.local(2010, 5, 1), Helpers.get_day_ago(5)
  end

  def test_wrap
    assert_equal [1], Helpers.wrap(1)
    assert_equal [], Helpers.wrap(nil)
    assert_equal [1], Helpers.wrap([1])
    assert_equal [{test: 1}, {test: 2}], Helpers.wrap([{test: 1}, {test: 2}])
    assert_equal [{test: 1}], Helpers.wrap({test: 1})
  end
end
