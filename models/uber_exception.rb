class UberException < Exceptionist::Model
  attr_accessor :id

  def initialize(id)
    @id = id
  end

  def self.count_all(project)
    redis.set_count("Exceptionist::Project:#{project}:UberExceptions")
  end

  def self.find_all(project)
    redis.set_members("Exceptionist::Project:#{project}:UberExceptions").map { |id| new(id) }
  end

  def self.find_all_sorted_by_time(project, filter, start, limit)
    set_key = "Exceptionist::Project:#{project}:UberExceptions"
    set_key << ":Filter:#{filter}" if filter
    redis.sort(set_key,
      :by => "Exceptionist::UberException:*:LastOccurredAt",
      :order => 'DESC',
      :limit => [start, limit]).map { |id| new(id) }
  rescue RuntimeError
    []
  end

  def self.find_all_sorted_by_occurrence_count(project, filter, start, limit)
    set_key = "Exceptionist::Project:#{project}:UberExceptions"
    set_key << ":Filter:#{filter}" if filter
    redis.sort(set_key,
      :by => "Exceptionist::UberException:*:OccurrenceCount",
      :order => 'DESC',
      :limit => [start, limit]).map { |id| new(id) }
  rescue RuntimeError
    []
  end

  def self.find_new_since(project, date)
    all = redis.sort("Exceptionist::Project:#{project}:UberExceptions",
            :by => "Exceptionist::UberException:*:OccurrenceCount",
            :order => 'DESC').map { |id| new(id) }

    all.select { |uber_exp| uber_exp.first_occurred_at >= date }
  end

  def self.occurred(occurrence)
    # every uber exception has a list of occurrences
    redis.push_tail("Exceptionist::UberException:#{occurrence.uber_key}:Occurrences", occurrence.id)

    # store the timestamp of the last occurrance to be able to sort by that
    redis.set("Exceptionist::UberException:#{occurrence.uber_key}:LastOccurredAt", occurrence.occurred_at.to_i)
    # store the occurrence count to be able to sort by that
    redis.incr("Exceptionist::UberException:#{occurrence.uber_key}:OccurrenceCount")

    # store a list of exceptions per project
    redis.set_add("Exceptionist::Project:#{occurrence.project_name}:UberExceptions", occurrence.uber_key)

    # Apply filters
    Exceptionist.filter.all.each do |filter|
      if filter.last.call(occurrence)
        redis.set_add("Exceptionist::Project:#{occurrence.project_name}:UberExceptions:Filter:#{filter.first}", occurrence.uber_key)
      end
    end

    # store a list of exceptions per project per day
    redis.push_tail("Exceptionist::Project:#{occurrence.project_name}:OnDay:#{occurrence.occurred_at.strftime('%Y-%m-%d')}", occurrence.id)

    # store a top level set of projects
    redis.set_add("Exceptionist::Projects", occurrence.project_name)
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
    Occurrence.find(redis.list_index(key(id, 'Occurrences'), position - 1))
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

  def occurrences_count
    @occurrences_count ||= redis.list_length(key(id, 'Occurrences'))
  end

  def ==(other)
    id == other.id
  end

  def inspect
    "(UberException: id: #{id})"
  end

private

  def occurrences_list(start_position, end_position)
    redis.list_range(key(id, 'Occurrences'), start_position, end_position)
  end
end
