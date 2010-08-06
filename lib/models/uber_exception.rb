class UberException
  attr_accessor :id

  def initialize(id)
    @id = id
  end

  def self.count_all(project)
    redis.zcard("Exceptionist::Project:#{project}:UberExceptions")
  end

  def self.find_all(project)
    uber_exceptions = redis.zrange("Exceptionist::Project:#{project}:UberExceptions", 0, -1) || []
    uber_exceptions.map { |id| new(id) }
  end

  def self.find_all_sorted_by_time(project, filter, start, limit)
    set_key = "Exceptionist::Project:#{project}:UberExceptions"
    set_key << ":Filter:#{filter}" if filter

    uber_exceptions = redis.zrevrange(set_key, start, start + limit - 1) || []
    uber_exceptions.map { |id| new(id) }
  rescue RuntimeError
    []
  end

  def self.find_all_sorted_by_occurrence_count(project, filter, start, limit)
    set_key = "Exceptionist::Project:#{project}:UberExceptions"
    set_key << ":Filter:#{filter}" if filter

    sort_key = "Exceptionist::UberException:*:OccurrenceCount"
    sort_key << ":Filter:#{filter}" if filter

    redis.sort(set_key, :by => sort_key, :order => 'DESC', :limit => [start, limit]).map { |id| new(id) }
  rescue RuntimeError
    []
  end

  def self.find_new_on(project, day)
    all = redis.sort("Exceptionist::Project:#{project}:UberExceptions",
            :by => "Exceptionist::UberException:*:OccurrenceCount",
            :order => 'DESC').map { |id| new(id) }

    next_day = day + 86400
    all.select { |uber_exp| uber_exp.first_occurred_at >= day && uber_exp.first_occurred_at < next_day }
  end

  def self.occurred(occurrence)
    # every uber exception has a sorted set of occurrences
    redis.zadd("Exceptionist::UberException:#{occurrence.uber_key}:Occurrences", occurrence.occurred_at.to_i, occurrence.id)

    # store the occurrence count to be able to sort by that
    redis.incr("Exceptionist::UberException:#{occurrence.uber_key}:OccurrenceCount")

    # store a sorted set of exceptions per project
    redis.zadd("Exceptionist::Project:#{occurrence.project_name}:UberExceptions", occurrence.occurred_at.to_i, occurrence.uber_key)

    # Apply filters
    Exceptionist.filter.all.each do |filter|
      if filter.last.call(occurrence)
        # store the occurrence count to be able to sort by that
        redis.incr("Exceptionist::UberException:#{occurrence.uber_key}:OccurrenceCount:Filter:#{filter.first}")

        # store a stored set of exceptions per project
        redis.zadd("Exceptionist::Project:#{occurrence.project_name}:UberExceptions:Filter:#{filter.first}", occurrence.occurred_at.to_i, occurrence.uber_key)
      end
    end

    # store a list of exceptions per project per day
    redis.rpush("Exceptionist::Project:#{occurrence.project_name}:OnDay:#{occurrence.occurred_at.strftime('%Y-%m-%d')}", occurrence.id)

    # store a top level set of projects
    redis.sadd("Exceptionist::Projects", occurrence.project_name)
  end

  def last_occurrence
    @last_occurrence ||= Occurrence.find(occurrences_list(-1, -1))
  end

  def first_occurrence
    @first_occurrence ||= Occurrence.find(occurrences_list(0, 0))
  end

  def occurrences
    Occurrence.find_all(occurrences_list(0, -1))
  end

  def current_occurrence(position)
    Occurrence.find(redis.zrange(key(id, 'Occurrences'), position - 1, position - 1))
  end

  def first_occurred_at
    first_occurrence.occurred_at
  end

  def last_occurred_at
    last_occurrence.occurred_at
  end

  def title
    last_occurrence.title
  end

  def url
    last_occurrence.url
  end

  def occurrences_count(filter = nil)
    count_key = "Exceptionist::UberException:#{id}:OccurrenceCount"
    count_key << ":Filter:#{filter}" if filter && filter != ''

    @occurrences_count ||= redis.get(count_key).to_i
  end

  def ==(other)
    id == other.id
  end

  def inspect
    "(UberException: id: #{id})"
  end

private

  def self.redis
    Exceptionist.redis
  end

  def redis
    Exceptionist.redis
  end

  def self.key(*parts)
    "#{Exceptionist.namespace}::#{name}:#{parts.join(':')}"
  end

  def key(*parts)
    self.class.key(*parts)
  end

  def occurrences_list(start_position, end_position)
    redis.zrange(key(id, 'Occurrences'), start_position, end_position)
  end
end
