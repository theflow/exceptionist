
require 'test_helper'

class UtilsTest < MiniTest::Test

  def setup
    clear_collections

    4.times do |i|
      UberException.occurred(create_occurrence(action_name:"action_#{i}"))
    end

    5.times do |i|
      create_deploy
    end

    Exceptionist.esclient.refresh
  end

  def test_export_occurrences
    assert_equal 4, Exceptionist.esclient.export('occurrences').count
  end

  def test_export_deploys
    assert_equal 5, Exceptionist.esclient.export('deploys').count
  end

end
