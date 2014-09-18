require 'test_helper'

class DeployTest < MiniTest::Test

  def setup
    clear_collections

    @deploy11 = create_deploy(version: '0.1.0')
    @deploy12 = create_deploy(version: '0.2.0')
    @deploy13 = create_deploy(version: '0.3.0')

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

    assert_equal nil, Deploy.find_last_deploy('NoProject')
  end

  def test_find_by_project_since
    create_deploy(version: '0.0.5', occurred_at: Time.now - 86400 * 6)
    @deploy101 = create_deploy(version: '0.0.9', occurred_at: Time.now - 86400 * 3)

    Exceptionist.esclient.refresh

    assert_equal [@deploy13, @deploy12, @deploy11, @deploy101], Deploy.find_by_project_since('ExampleProject', Time.now - 86400 * 5)
  end

end
