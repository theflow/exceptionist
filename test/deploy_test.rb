require 'test_helper'

class DeployTest < AbstractTest

  def test_save
    deploy = create_deploy

    Exceptionist.esclient.refresh

    assert_equal deploy, Deploy.find_all('ExampleProject').first
    assert_equal 0, Deploy.find_all('OtherProject').count
  end
end
