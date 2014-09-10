require 'test_helper'

class DeployTest < AbstractTest

  def test_save
    deploy = create_deploy

    Exceptionist.esclient.refresh

    assert_equal deploy, Deploy.find_all('ExampleProject').first
    assert_equal 0, Deploy.find_all('OtherProject').count
  end

  def test_find_all
    create_deploy
    create_deploy( version: '0.0.2' )
    create_deploy( project_name: 'OtherProject' )

    Exceptionist.esclient.refresh

    assert_equal 2, Deploy.find_all('ExampleProject').count
    assert_equal 1, Deploy.find_all('OtherProject').count
  end
end
