class Project

  attr_accessor :name

  def initialize(name)
    @name = name
  end

  def exceptions_count
    UberException.count_all(name)
  end

  def last_thirty_days
    Helper.last_n_days(30).map { |day| [day,  Occurrence.count(filters: [{ term: { project_name: name } }, { range: { occurred_at: Helper.day_range(day) } }] )] }
  end

  def last_deploy
    Deploy.find_last_deploy(name)
  end

  def deploys_last_thirty_days
    since = Helper.get_day_ago(30)
    Deploy.find_by_project_since(@name, since)
  end

  def self.find_by_key(api_key)
    project = Exceptionist.projects.find { |name, project_key| project_key == api_key }
    project ? Project.new(project.first) : nil
  end

  def self.all
    Exceptionist.projects.map { |name, api_key| Project.new(name) }
  end

  def ==(other)
    name == other.name
  end

  def inspect
    "(Project name=#{name})"
  end
end
