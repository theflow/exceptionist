require 'test_helper'

class DeployTest < AbstractTest

  def test_save
    deploy = create_deploy

    Exceptionist.esclient.refresh

    assert_equal deploy, Deploy.find('ExampleProject').first
    assert_equal 0, Deploy.find('OtherProject').count
  end

  def test_save_with_deploy_time
    deploy = create_deploy( deploy_time: '2014-09-10T14:45:42.125+0200' )

    Exceptionist.esclient.refresh

    assert_equal deploy, Deploy.find('ExampleProject').first
    assert_equal 0, Deploy.find('OtherProject').count
  end

  def test_find_all
    create_deploy
    create_deploy( version: '0.0.2' )
    create_deploy( project_name: 'OtherProject' )

    Exceptionist.esclient.refresh

    assert_equal 2, Deploy.find('ExampleProject').count
    assert_equal 1, Deploy.find('OtherProject').count
  end

  def test_find_last_deploy
    assert_nil Deploy.find_last_deploy('ExampleProject')

    create_deploy
    deploy = create_deploy( version: '0.0.2' )
    deploy_other_project = create_deploy( project_name: 'OtherProject' )

    Exceptionist.esclient.refresh

    assert_equal deploy, Deploy.find_last_deploy('ExampleProject')
    assert_equal deploy_other_project, Deploy.find_last_deploy('OtherProject')
  end
end
