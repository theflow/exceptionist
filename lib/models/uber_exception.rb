class UberException
  attr_accessor :id, :project_name, :occurrences_count, :closed, :last_occurrence, :first_occurred_at, :category

  def initialize(attributes)
    @id = attributes[:id]
    @project_name = attributes[:project_name]
    @occurrences_count = attributes[:occurrences_count]
    @closed = attributes[:closed]
    @last_occurrence = Occurrence.new(attributes[:last_occurrence])
    @first_occurred_at = Time.parse(attributes[:first_occurred_at])
  end

  def self.count_all(project)
    Exceptionist.esclient.count(type: 'exceptions', filters: { term: { project_name: project } } )
  end

  def self.count_since(project: '', date: '')
    Exceptionist.esclient.count(type: 'exceptions', filters: [ { term: { project_name: project } }, range: { 'last_occurrence.occurred_at' => { gte: date.strftime("%Y-%m-%dT%H:%M:%S.%L%z") } } ] )
  end

  def self.get(uber_key)
    Exceptionist.esclient.get_exception(uber_key)
  end

  def self.find_sorted_by_occurrences_count(project: '', from: 0, size: 25)
    UberException.find(project: project, sort: { occurrences_count: { order: 'desc'} }, from: from, size: size)
  end

  def self.find_since_last_deploy(project: '', from: 0, size: 25)
    deploy = Deploy.find_last_deploy(project)
    return nil unless deploy
    agg_exces = Exceptionist.esclient.search_aggs([ { term: { project_name: project } }, { range: { occurred_at: { gte: deploy.occurred_at.strftime("%Y-%m-%dT%H:%M:%S.%L%z") } } } ],'uber_key')
    ids = []
    agg_exces.each { |occurr| ids << occurr['key'] }
    exces = find( project: project, filters: { ids: { type: 'exceptions', values: ids } }, from: from, size: size )
    exces.each do |exce|
      agg_exces.each do |occurr|
        if occurr['key'] == exce.id
          exce.occurrences_count = occurr['doc_count']
          agg_exces.delete(occurr)
          break
        end
      end
    end
    exces
  end

  def self.find_since_last_deploy_ordered_by_occurrences_count(project: '', from: 0, size: 25)
    deploy = Deploy.find_last_deploy(project)
    return nil unless deploy
    agg_exces = Exceptionist.esclient.search_aggs([ { term: { project_name: project } }, { range: { occurred_at: { gte: deploy.occurred_at.strftime("%Y-%m-%dT%H:%M:%S.%L%z") } } } ],'uber_key')
    ids = []
    agg_exces.each { |occurr| ids << occurr['key'] }
    exces = Exceptionist.esclient.mget(ids: ids.slice!(from, size))
    exces.each do |exce|
      agg_exces.each do |occurr|
        if occurr['key'] == exce.id
          exce.occurrences_count = occurr['doc_count']
          agg_exces.delete(occurr)
          break
        end
      end
    end
    exces
  end

  def self.find(project: '', filters: [], sort: { 'last_occurrence.occurred_at' => { order: 'desc'} }, from: 0, size: 25)
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
    first_timestamp = occurrence.occurred_at

    #TODO maybe remove when events arrive sorted
    begin
      exec = Exceptionist.esclient.get_exception(occurrence.uber_key)
      occurrence = exec.last_occurrence.occurred_at < first_timestamp ? occurrence : exec.last_occurrence
      first_timestamp = first_timestamp < exec.first_occurred_at ? first_timestamp :  exec.first_occurred_at
    rescue Elasticsearch::Transport::Transport::Errors::NotFound

    end

    first_timestamp = first_timestamp.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
    hash = occurrence.to_hash
    hash[:id] = occurrence.id
    Exceptionist.esclient.update('exceptions', occurrence.uber_key, { script: 'ctx._source.occurrences_count += 1; ctx._source.closed=false; ctx._source.last_occurrence=occurrence; ctx._source.first_occurred_at=timestamp',
                                                                      upsert: { project_name: occurrence.project_name, last_occurrence: hash, first_occurred_at: first_timestamp, closed: false, occurrences_count: 1},
                                                                      params: { occurrence: hash, timestamp: first_timestamp} })
    Exceptionist.esclient.get_exception(occurrence.uber_key)
  end

  def self.forget_old_exceptions(project, days=0)
    since_date = Time.now - (86400 * days)
    deleted = 0

    uber_exceptions = Exceptionist.esclient.search_exceptions( filters: [ { term: { project_name: project } }, range: { 'last_occurrence.occurred_at' => { lte: since_date.strftime("%Y-%m-%dT%H:%M:%S.%L%z") } } ] )

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

  def current_occurrence(position)
    occurrences = Occurrence.find(uber_key: id, sort: { occurred_at: { order: 'asc'} }, from: position - 1, size: 1)
    occurrences.any? ? occurrences.first : nil
  end

  def new_since_last_deploy
    deploy = Deploy.find_last_deploy(@project_name)
    deploy.nil? ? true : deploy.occurred_at < @first_occurred_at
  end

  #
  # accessors
  #

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
