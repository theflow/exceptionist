class UberException
  attr_accessor :id, :project_name, :occurrences_count

  def initialize(attributes)
    @id = attributes['_id']
    @project_name = attributes['project_name']
    @occurrences_count = attributes['occurrence_count']
  end

  def self.count_all(project)
    Exceptionist.mongo['exceptions'].find({:project_name => project, :closed => {'$exists' => false}}).count
  end

  def self.find(uber_key)
    new(Exceptionist.mongo['exceptions'].find_one({:_id => uber_key}))
  end

  def self.find_all(project)
    uber_exceptions = Exceptionist.mongo['exceptions'].find({:project_name => project, :closed => {'$exists' => false}})
    uber_exceptions.map { |doc| new(doc) }
  end

  def self.find_all_sorted_by_time(project, start, limit)
    uber_exceptions = Exceptionist.mongo['exceptions'].find({:project_name => project, :closed => {'$exists' => false}}, :skip => start, :limit => limit, :sort => [:occurred_at, :desc])
    uber_exceptions.map { |doc| new(doc) }
  end

  def self.find_all_sorted_by_occurrence_count(project, start, limit)
    uber_exceptions = Exceptionist.mongo['exceptions'].find({:project_name => project, :closed => {'$exists' => false}}, :skip => start, :limit => limit, :sort => [:occurrence_count, :desc])
    uber_exceptions.map { |doc| new(doc) }
  end

  def self.find_new_on(project, day)
    next_day = day + 86400
    uber_keys = Exceptionist.mongo['occurrences'].distinct(:uber_key, {:occurred_at_day => day.strftime('%Y-%m-%d')})
    uber_exceptions = Exceptionist.mongo['exceptions'].find({:_id => {'$in' => uber_keys}}).map { |doc| new(doc) }

    uber_exceptions.select { |uber_exp| uber_exp.first_occurred_at >= day && uber_exp.first_occurred_at < next_day }
  end

  def self.occurred(occurrence)
    # upsert the UberException
    Exceptionist.mongo['exceptions'].update(
      {:_id => occurrence.uber_key},
      {
        "$set" => {:project_name => occurrence.project_name, :occurred_at => occurrence.occurred_at},
        "$inc" => {:occurrence_count => 1}
      },
      :upsert => true, :safe => true
    )

    # return the UberException
    new('_id' => occurrence.uber_key)
  end

  def self.forget_old_exceptions(project, days)
    since_date = Time.now - (84600 * days)
    deleted = 0

    uber_exceptions = Exceptionist.mongo['exceptions'].find({:occurred_at => {'$lt' => since_date}})
    uber_exceptions.each do |doc|
      UberException.new(doc).forget!
      deleted += 1
    end

    deleted
  end

  def forget!
    Occurrence.delete_all_for(id)
    Exceptionist.mongo['exceptions'].remove({:_id => id}, :safe => true)
  end

  def close!
    Exceptionist.mongo['exceptions'].update({:_id => id}, {'$set' => {'closed' => true}})
  end

  def last_occurrence
    @last_occurrence ||= Occurrence.find_last_for(id)
  end

  def first_occurrence
    @first_occurrence ||= Occurrence.find_first_for(id)
  end

  def current_occurrence(position)
    Occurrence.new(Exceptionist.mongo['occurrences'].find({:uber_key => id}, :sort => [:occurred_at, :asc], :skip => position - 1, :limit => 1).first)
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

  def occurrence_count_on(date)
    Exceptionist.mongo['occurrences'].find({:uber_key => id, :occurred_at_day => date.strftime('%Y-%m-%d')}).count
  end

  def last_thirty_days
    Project.last_n_days(30).map { |day| [day, occurrence_count_on(day)] }
  end

  def ==(other)
    id == other.id
  end

  def inspect
    "(UberException: id: #{id})"
  end
end
