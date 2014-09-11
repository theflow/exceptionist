class UberException
  attr_accessor :id, :project_name, :occurrences_count, :closed, :last_occurred_at

  def initialize(attributes)
    @id = attributes[:id]
    @project_name = attributes[:project_name]
    @occurrences_count = attributes[:occurrences_count]
    @closed = attributes[:closed]
  end

  def self.create_es(attributes)
    attributes.merge!(attributes['_source']).delete('_source')
    UberException.new(attributes)
  end

  def self.count_all(project)
    Exceptionist.esclient.count(type: 'exceptions', terms: { term: { project_name: project } } )
  end

  def self.get(uber_key)
    Exceptionist.esclient.get_exception(uber_key)
  end

  def self.find_all(project)
    Exceptionist.esclient.search_exceptions(filters: [ { term: { project_name: project } }, { term: { closed: false } } ])
  end

  def self.find_all_sorted_by_time(project, from, size)
    Exceptionist.esclient.search_exceptions(filters: [ { term: { project_name: project } }, { term: { closed: false } } ], sort: { last_occurred_at: { order: 'desc'} }, from: from, size: size)
  end

  def self.find_all_sorted_by_time_since(project, since, from, size)
    Exceptionist.esclient.search_exceptions(filters: [ { term: { project_name: project } }, { term: { closed: false } }, range: { last_occurred_at: { gte: since.strftime("%Y-%m-%dT%H:%M:%S.%L%z") } } ], sort: { last_occurred_at: { order: 'desc'} }, from: from, size: size)
  end

  def self.find_all_sorted_by_occurrences_count(project, from, size)
    Exceptionist.esclient.search_exceptions(filters: [ { term: { project_name: project } }, { term: { closed: false } } ], sort: { occurrences_count: { order: 'desc' } }, from: from, size: size )
  end

  def self.find_all_sorted_by_occurrences_count_since(project, since, from, size)
    Exceptionist.esclient.search_exceptions([ { term: { project_name: project } }, { term: { closed: false } }, range: { last_occurred_at: { gte: since.strftime("%Y-%m-%dT%H:%M:%S.%L%z") } } ], { occurrences_count: { order: 'desc'} }, from: from, size: size)
  end

  def self.find_new_on(project, day)
    next_day = day + 86400

    buckets = Exceptionist.esclient.search_aggs({ term: { occurred_at_day: day.strftime('%Y-%m-%d') } }, 'uber_key' )
    uber_exceptions = Exceptionist.esclient.search_ids('exceptions', buckets.map { |occ| occ['key'] } )

    uber_exceptions.select { |uber_exp| uber_exp.first_occurred_at >= day && uber_exp.first_occurred_at < next_day }
  end



  def self.occurred(occurrence)
    Exceptionist.esclient.update('exceptions', occurrence.uber_key, { script: 'ctx._source.occurrences_count += 1', upsert:
        { project_name: occurrence.project_name, last_occurred_at: occurrence.occurred_at.strftime("%Y-%m-%dT%H:%M:%S.%L%z"), closed: false, occurrences_count: 1 } })
    Exceptionist.esclient.get_exception(occurrence.uber_key)
  end

  def self.forget_old_exceptions(project, days)
    since_date = Time.now - (86400 * days)
    deleted = 0

    uber_exceptions = Exceptionist.esclient.search_exceptions( filters: [ { term: { project_name: project } }, range: { last_occurred_at: { lte: since_date.strftime("%Y-%m-%dT%H:%M:%S.%L%z") } } ] )

    uber_exceptions.each do |exception|
      exception.forget!
      deleted += 1
    end

    deleted
  end

  def forget!
    Occurrence.delete_all_for(id)

    Exceptionist.esclient.delete('exceptions', id)
  end

  def close!
    Exceptionist.esclient.update('exceptions', @id, { doc: { closed: true } })
  end

  def last_occurrence
    @last_occurrence ||= Occurrence.find_last_for(id)
  end

  def first_occurrence
    @first_occurrence ||= Occurrence.find_first_for(id)
  end

  def current_occurrence(position)
    Occurrence.find(uber_key: id, sort: { occurred_at: { order: 'asc'} }, position: position - 1)
  end

  def update_occurrences_count
    @occurrences_count = Exceptionist.esclient.count(terms: { term: { uber_key: id } })
    Exceptionist.esclient.update('exceptions', id, { doc: { occurrences_count: @occurrences_count } })
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

  def occurrences_count_on(date)
    Occurrence.count_all_on(project_name, date)
  end

  def last_thirty_days
    Project.last_n_days(30).map { |day| [day, occurrences_count_on(day)] }
  end

  def ==(other)
    id == other.id
  end

end
