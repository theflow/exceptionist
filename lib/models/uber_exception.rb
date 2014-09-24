class UberException

  attr_accessor :id, :project_name, :occurrences_count, :closed, :last_occurrence, :first_occurred_at, :category

  TYPE_EXCEPTIONS = 'exceptions'

  def initialize(attributes)
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    @last_occurrence = Occurrence.new(attributes[:last_occurrence])
    @first_occurred_at = Time.parse(self.first_occurred_at) if self.first_occurred_at.is_a? String
  end

  def self.count_all(project)
    Exceptionist.esclient.count(type: TYPE_EXCEPTIONS, filters: { term: { project_name: project } } )
  end

  def self.count_since(project: '', date: '')
    Exceptionist.esclient.count(type: TYPE_EXCEPTIONS, filters: [ { term: { project_name: project } }, range: { 'last_occurrence.occurred_at' => { gte: Helper.es_time(date) } } ] )
  end

  def self.get(uber_key)
    new(Helper.transform(Exceptionist.esclient.get(type: TYPE_EXCEPTIONS, id: uber_key)))
  end

  def self.find_sorted_by_occurrences_count(terms: [], from: 0, size: 25)
    UberException.find(terms: terms, sort: { occurrences_count: { order: 'desc'} }, from: from, size: size)
  end

  def self.find_since_last_deploy(project: '', terms: [], from: 0, size: 25)
    agg_exces, ids = aggregation_since_last_deploy(project)

    exces = find( terms: terms.compact << { closed: false }, filters: [ { ids: { type: TYPE_EXCEPTIONS, values: ids } } ], from: from, size: size )
    merge(exces, agg_exces)
  end

  def self.find_since_last_deploy_ordered_by_occurrences_count(project: '', category: nil, from: 0, size: 25)
    agg_exces, ids = aggregation_since_last_deploy(project)

    # to preserve ordering and filtering category at the same time, filtering has to be done in ruby, not on db-level
    exces = Exceptionist.esclient.mget(type: TYPE_EXCEPTIONS, ids: ids).map { |doc| new(Helper.transform(doc)) }
    exces.select!{ |exce| exce.category == category && !exce.closed } unless category.nil?
    merge(exces.slice(from, size), agg_exces)
  end

  def self.aggregation_since_last_deploy(project)
    deploy = Deploy.find_last_deploy(project)
    raise 'There is no deploy' if deploy.nil?

    filters_occur = [{ term: { project_name: project } }, { range: { occurred_at: { gte: Helper.es_time(deploy.occurred_at) } } } ]
    agg_exces = Occurrence.search_aggs(filters: filters_occur, aggs: 'uber_key')
    ids = []
    agg_exces.each { |occurr| ids << occurr['key'] }

    return agg_exces, ids
  end

  def self.merge(exces, agg_exces)
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

  def self.find(terms: [], filters: [], sort: { 'last_occurrence.occurred_at' => { order: 'desc'} }, from: 0, size: 25)
    terms = terms.map { |term| { term: term } unless term.nil? }
    terms << { term: { closed: false } }

    hash = Exceptionist.esclient.search(type: TYPE_EXCEPTIONS, filters: terms.push(*filters), sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| new(Helper.transform(doc)) }
  end

  def self.occurred(occurrence)
    first_timestamp = occurrence.occurred_at

    #TODO maybe remove when events arrive sorted
    begin
      exec = UberException.get(occurrence.uber_key)
      occurrence = exec.last_occurrence.occurred_at < first_timestamp ? occurrence : exec.last_occurrence
      first_timestamp = first_timestamp < exec.first_occurred_at ? first_timestamp :  exec.first_occurred_at
    rescue Elasticsearch::Transport::Transport::Errors::NotFound

    end

    first_timestamp = Helper.es_time(first_timestamp)
    hash = occurrence.to_hash
    hash[:id] = occurrence.id
    Exceptionist.esclient.update(type: TYPE_EXCEPTIONS, id: occurrence.uber_key, body: { script: 'ctx._source.occurrences_count += 1; ctx._source.closed=false; ctx._source.last_occurrence=occurrence; ctx._source.first_occurred_at=timestamp',
                                                                      upsert: { project_name: occurrence.project_name, last_occurrence: hash, first_occurred_at: first_timestamp, closed: false, occurrences_count: 1, category: 'no-category'},
                                                                      params: { occurrence: hash, timestamp: first_timestamp} })
    UberException.get(occurrence.uber_key)
  end

  def self.forget_old_exceptions(project, days=0)
    since_date = Time.now - (86400 * days)
    deleted = 0

    uber_exceptions = find( filters: [ { term: { project_name: project } }, range: { 'last_occurrence.occurred_at' => { lte: Helper.es_time(since_date) } } ] )

    uber_exceptions.each do |exception|
      exception.forget!
      deleted += 1
    end

    deleted
  end

  def forget!
    Occurrence.delete_all_for(id)

    Exceptionist.esclient.delete(type: TYPE_EXCEPTIONS, id: id)
  end

  def close!
    Exceptionist.esclient.update(type: TYPE_EXCEPTIONS, id: @id, body: { doc: { closed: true } })
  end

  def update(doc)
    Exceptionist.esclient.update(type: TYPE_EXCEPTIONS, id: @id, body: { doc: doc })
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
    Occurrence.count( filters: [ { term: { uber_key: @id } }, { term: { occurred_at_day: Helper.es_day(date) } } ] )
  end

  def last_thirty_days
    Helper.last_n_days(30).map { |day| [day, occurrences_count_on(day)] }
  end

  def ==(other)
    id == other.id
  end

  def inspect
    "(UberException id=#{id})"
  end
end
