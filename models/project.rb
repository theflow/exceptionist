class Project
  attr_accessor :name

  def initialize(name)
    self.name = name
  end

  def exceptions_count
    UberException.count_all(name)
  end

  def last_thirty_days
    today = Time.now
    start = today - (3600 * 24 * 29) # 29 days ago

    thirty_days = []
    begin
      thirty_days << [start, occurrence_count_on(start)]
    end while (start += 86400) <= today

    thirty_days
  end

  def occurrence_count_on(date)
    redis.list_length("Exceptionist::Project:#{name}:OnDay:#{date.strftime('%Y-%m-%d')}")
  end

  def last_three_exceptions
    latest_exceptions(0, 3)
  end

  def latest_exceptions(start, limit = 25)
    UberException.find_all_sorted_by_time(name, start, limit)
  end

  def most_frequest_exceptions(start, limit = 25)
    UberException.find_all_sorted_by_occurrence_count(name, start, limit)
  end

  def ==(other)
    name == other.name
  end

  def self.all
    redis.set_members('Exceptionist::Projects').map { |name| Project.new(name) }
  end
end
