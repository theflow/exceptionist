class Project
  attr_accessor :name

  def initialize(name)
    self.name = name
  end

  def exceptions_count
    UberException.count_all(name)
  end

  def last_thirty_days
    Project.last_n_days(30).map { |day| [day, occurrence_count_on(day)] }
  end

  def self.last_n_days(days)
    today = Time.now
    start = today - (3600 * 24 * (days - 1)) # `days` days ago

    n_days = []
    begin
      n_days << Time.utc(start.year, start.month, start.day)
    end while (start += 86400) <= today

    n_days
  end

  def occurrence_count_on(date)
    Occurrence.count_all_on(name, date)
  end

  def latest_exceptions(start, limit = 25)
    UberException.find_all_sorted_by_time(name, start, limit)
  end

  def most_frequest_exceptions(start, limit = 25)
    UberException.find_all_sorted_by_occurrences_count(name, start, limit)
  end

  def new_exceptions_on(day)
    UberException.find_new_on(name, day)
  end

  def total_count_on(day)
    Occurrence.count_all_on(name, day)
  end

  def ==(other)
    name == other.name
  end

  def self.find_by_key(api_key)
    project = Exceptionist.projects.find { |name, project_key| project_key == api_key }
    project ? Project.new(project.first) : nil
  end

  def self.all
    Exceptionist.projects.map { |name, api_key| Project.new(name) }
  end
end
