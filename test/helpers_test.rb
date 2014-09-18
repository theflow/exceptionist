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
end
