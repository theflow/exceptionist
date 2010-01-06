class Project
  attr_accessor :name

  def initialize(name)
    self.name = name
  end

  def exceptions_count
    UberException.count_all(name)
  end

  def last_three_exceptions
    latest_exceptions(0, 3)
  end

  def latest_exceptions(start, limit = 25)
    UberException.find_all_sorted_by_time(name, start, limit)
  end

  def ==(other)
    name == other.name
  end

  def self.all
    redis.set_members('Exceptionist::Projects').map { |name| Project.new(name) }
  end
end
