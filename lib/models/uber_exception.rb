class UberException
  attr_accessor :id, :project_name, :occurrences_count, :closed, :last_occurred_at

  def initialize(attributes)
    @id = attributes[:id]
    @project_name = attributes[:project_name]
    @occurrences_count = attributes[:occurrences_count]
    @closed = attributes[:closed]
    @last_occurred_at = Time.parse(attributes[:last_occurred_at])
  end

  def self.count_all(project)
    Exceptionist.esclient.count(type: 'exceptions', filters: { term: { project_name: project } } )
  end

  def self.get(uber_key)
    Exceptionist.esclient.get_exception(uber_key)
  end

  def self.find_sorted_by_occurrences_count(project, from = 0, size = 50)
    UberException.find(project: project, sort: { occurrences_count: { order: 'desc'} }, from: from, size: size)
  end

  def self.find_since_last_deploy(project)
    deploy = Deploy.find_last_deploy(project)
    occurrences = Exceptionist.esclient.search_aggs([ { term: { project_name: project } }, { range: { occurred_at: { gte: deploy.deploy_time } } } ],'uber_key')
    ids = []
    occurrences.each { |occurr| ids << occurr['key'] }
    exces = find( project: project, filters: { ids: { type: 'exceptions', values: ids } } )
    occurrences.each do |occurr|
      exces.each do |exce|
        if occurr['key'] == exce.id
          exce.occurrences_count = occurr['doc_count']
          break
        end
      end
    end
    exces
  end

  def self.find(project: '', filters: [], sort: { last_occurred_at: { order: 'desc'} }, from: 0, size: 50)
    raise ArgumentError, 'position has to be >= 0' if from < 0

    filters = [filters] if filters.class == Hash
    filters << { term: { closed: false } } << { term: { project_name: project } }
    Exceptionist.esclient.search_exceptions(filters: filters, sort: sort, from: from, size: size)
  end

  def self.find_new_on(project, day)
    next_day = day + 86400

    buckets = Exceptionist.esclient.search_aggs({ term: { occurred_at_day: day.strftime('%Y-%m-%d') } }, 'uber_key' )
    uber_exceptions = Exceptionist.esclient.search_ids('exceptions', buckets.map { |occ| occ['key'] } )

    uber_exceptions.select { |uber_exp| uber_exp.first_occurred_at >= day && uber_exp.first_occurred_at < next_day }
  end



  def self.occurred(occurrence)
    timestamp = occurrence.occurred_at.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
    Exceptionist.esclient.update('exceptions', occurrence.uber_key, { script: 'ctx._source.occurrences_count += 1; ctx._source.last_occurred_at=last_occurred_at; ctx._source.closed=closed',
                                                                      upsert: { project_name: occurrence.project_name, last_occurred_at: timestamp, closed: false, occurrences_count: 1},
                                                                      params: { last_occurred_at: timestamp, closed: false} })
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
    occurrences = Occurrence.find(uber_key: id, sort: { occurred_at: { order: 'asc'} }, from: position - 1, size: 1)
    occurrences.any? ? occurrences.first : nil
  end

  def update_occurrences_count
    occurrences_count = Occurrence.count(filters: { term: { uber_key: id } })
    Exceptionist.esclient.update('exceptions', id, { doc: { occurrences_count: occurrences_count } })
  end

  def first_occurred_at
    first_occurrence.occurred_at
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

  def inspect
    "(UberException id=#{id})"
  end
end
