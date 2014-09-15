require 'test_helper'

class ProjectTest < AbstractTest

  def test_last_n_days
    assert_equal 2, Project.last_n_days(2).size
    assert_equal 4, Project.last_n_days(4).size
  end

  def test_exceptions_count
    project = Project.new("ExampleProject")

    assert_equal 0, project.exceptions_count
  end


  def test_last_thirty_days
    project = Project.new('ExampleProject')

    project.last_thirty_days.each do |day, occur|
      assert_equal 0, occur
    end

    create_occurrence

    Exceptionist.esclient.refresh

    assert_equal 1, project.last_thirty_days.last[1]
  end

  def test_last_deploy
    project = Project.new("ExampleProject")

    assert_equal nil, project.last_deploy
  end

  def test_find_by_key
    assert_equal nil, Project.find_by_key('test_key')

    Exceptionist.add_project('project', 'test_key')

    assert_equal 'project', Project.find_by_key('test_key').name
  end

  def test_find_by_key
    assert_equal nil, Project.find_by_key('test_key')

    Exceptionist.add_project('project', 'test_key')

    assert_equal 'project', Project.find_by_key('test_key').name
  end

end
