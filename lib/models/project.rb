class Project
  attr_accessor :name

  def initialize(name)
    self.name = name
  end

  def exceptions_count
    UberException.count_all(name)
  end

  def last_thirty_days
    last_n_days(30).map { |day| [Time.utc(day.year, day.month, day.day), occurrence_count_on(day)] }
  end

  def last_n_days(days)
    today = Time.now
    start = today - (3600 * 24 * (days - 1)) # `days` days ago

    n_days = []
    begin
      n_days << start
    end while (start += 86400) <= today

    n_days
  end

  def occurrence_count_on(date)
    # Exceptionist.mongo['occurrences'].group({
    #   :keyf => "function() { Date.UTC(this.date.getFullYear(), this.date.getMonth(), this.date.getDate()) }"
    #   :cond => {:project_name => name}
    #   :initial => {:count => 0},
    #   :reduce => "function(obj, prev) { prev.csum += 1; }",
    # })
    Exceptionist.mongo['occurrences'].find({:project_name => name, :occurred_at_day => date.strftime('%Y-%m-%d')}).count
  end

  def latest_exceptions(start, limit = 25)
    UberException.find_all_sorted_by_time(name, start, limit)
  end

  def most_frequest_exceptions(start, limit = 25)
    UberException.find_all_sorted_by_occurrence_count(name, start, limit)
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

  def self.all
    Exceptionist.mongo['exceptions'].distinct(:project_name).map { |name| Project.new(name) }
  end
end
