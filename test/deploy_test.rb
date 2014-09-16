require 'test_helper'

class DeployTest < MiniTest::Test

  def setup
    clear_collections

    @deploy11 = create_deploy(version: '0.0.1')
    @deploy12 = create_deploy(version: '0.0.2')
    @deploy13 = create_deploy(version: '0.0.3')

    @deploy21 = create_deploy(project_name: 'OtherProject', version: '1.0.0')

    Exceptionist.esclient.refresh
  end


  def test_save
    assert_equal [@deploy13, @deploy12, @deploy11], Deploy.find_by_project('ExampleProject')
    assert_equal [@deploy21], Deploy.find_by_project('OtherProject')
  end

  def test_find_last_deploy
    assert_equal @deploy13, Deploy.find_last_deploy('ExampleProject')
    assert_equal @deploy21, Deploy.find_last_deploy('OtherProject')
  end
end
