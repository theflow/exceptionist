class Project
  attr_accessor :name

  def initialize(name)
    self.name = name
  end

  def exceptions_count
    UberException.count_all(name)
  end

  def last_thirty_days
    Project.last_n_days(30).map { |day| [Time.utc(day.year, day.month, day.day), occurrence_count_on(day)] }

    # counts_on_day = {}
    #
    # thirty_days_ago = Time.now - (3600 * 24 * 31)
    # groups = Exceptionist.mongo['occurrences'].group({
    #   :key => :occurred_at_day,
    #   :cond => {:project_name => 'podio-api', :occurred_at_day => {'$gte' => thirty_days_ago.strftime('%Y-%m-%d')}},
    #   :initial => {:count => 0},
    #   :reduce => "function(obj, prev) { prev.count += 1; }"
    # })
    #
    # groups.each do |group|
    #   counts_on_day[Time.utc(*group['occurred_at_day'].split('-'))] = group['count'].to_i
    # end
    #
    # last_n_days(30).map do |day|
    #   day_as_time = Time.utc(day.year, day.month, day.day)
    #   [day_as_time, counts_on_day[day_as_time]]
    # end
  end

  def self.last_n_days(days)
    today = Time.now
    start = today - (3600 * 24 * (days - 1)) # `days` days ago

    n_days = []
    begin
      n_days << start
    end while (start += 86400) <= today

    n_days
  end

  def occurrence_count_on(date)
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
