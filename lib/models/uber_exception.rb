class UberException

  attr_accessor :id, :project_name, :occurrences_count, :closed, :last_occurrence, :first_occurred_at, :category

  ES_TYPE = 'exceptions'

  def initialize(attributes = {})
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    @last_occurrence = Occurrence.new(attributes[:last_occurrence])
    @first_occurred_at = Time.parse(first_occurred_at) if first_occurred_at.is_a? String
  end

  def self.count_all(project)
    Exceptionist.esclient.count(type: ES_TYPE, filters: { term: { project_name: project } } )
  end

  def self.count_since(project: '', date: '')
    Exceptionist.esclient.count(type: ES_TYPE, filters: [{ term: { project_name: project } },
                                                           range: { 'last_occurrence.occurred_at' => { gte: Helper.es_time(date) } }] )
  end

  def self.get(uber_key)
    new(Helper.transform(Exceptionist.esclient.get(type: ES_TYPE, id: uber_key)))
  end

  def self.find_sorted_by_occurrences_count(terms: [], from: 0, size: 25)
    find(terms: terms, sort: { occurrences_count: { order: 'desc'} }, from: from, size: size)
  end

  def self.find_since_last_deploy(project: '', terms: [], from: 0, size: 25)
    aggregation, ids = aggregation_since_last_deploy(project)

    exceptions = find(terms: terms.compact << { closed: false }, filters: [{ ids: { type: ES_TYPE, values: ids } }], from: from, size: size)
    merge(exceptions, aggregation)
  end

  def self.find_since_last_deploy_ordered_by_occurrences_count(project: '', category: nil, from: 0, size: 25)
    agg_exceptions, ids = aggregation_since_last_deploy(project)

    # to preserve ordering and filtering category at the same time, filtering has to be done in ruby, not on db-level
    exceptions = Exceptionist.esclient.mget(type: ES_TYPE, ids: ids).map { |doc| new(Helper.transform(doc)) }
    exceptions.select!{ |exception| exception.category == category && !exception.closed } unless category.nil?
    merge(exceptions.slice(from, size), agg_exceptions)
  end

  def self.aggregation_since_last_deploy(project)
    deploy = Deploy.find_last_deploy(project)
    raise 'There is no deploy' if deploy.nil?

    filters_occurrence = [{ term: { project_name: project } }, { range: { occurred_at: { gte: Helper.es_time(deploy.occurred_at) } } }]
    agg_exceptions = Occurrence.aggregation(filters: filters_occurrence, aggregation: 'uber_key')
    ids = []
    agg_exceptions.each { |occurrence| ids << occurrence['key'] }

    return agg_exceptions, ids
  end

  def self.merge(exceptions, aggregation)
    exceptions.each do |exception|
      aggregation.each do |occurrence|
        if occurrence['key'] == exception.id
          exception.occurrences_count = occurrence['doc_count']
          aggregation.delete(occurrence)
          break
        end
      end
    end
    exceptions
  end

  def self.find(terms: [], filters: [], sort: { 'last_occurrence.occurred_at' => { order: 'desc'} }, from: 0, size: 25)
    terms = terms.map { |term| { term: term } unless term.nil? }
    terms << { term: { closed: false } }

    hash = Exceptionist.esclient.search(type: ES_TYPE, filters: terms.push(*filters), sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| new(Helper.transform(doc)) }
  end

  def self.occurred(occurrence)
    first_timestamp = occurrence.occurred_at

    #TODO maybe remove when events arrive sorted
    begin
      exec = get(occurrence.uber_key)
      occurrence = exec.last_occurrence.occurred_at < first_timestamp ? occurrence : exec.last_occurrence
      first_timestamp = first_timestamp < exec.first_occurred_at ? first_timestamp :  exec.first_occurred_at
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      # get throws NotFound exception when there is no exception with this uber_key
      # we could also search with a query but then we have to handle the null value and it would be slower
    end

    occurrence_hash = occurrence.create_es_hash
    occurrence_hash[:id] = occurrence.id

    script = 'ctx._source.occurrences_count += 1; ctx._source.closed=false; ctx._source.last_occurrence=var_occurrence; ctx._source.first_occurred_at=var_timestamp'
    body = { project_name: occurrence.project_name, last_occurrence: occurrence_hash, first_occurred_at: Helper.es_time(first_timestamp), closed: false, occurrences_count: 1, category: 'no-category'}
    Exceptionist.esclient.update(type: ES_TYPE, id: occurrence.uber_key,
                                 body: {
                                     script: script,
                                     params: { var_occurrence: occurrence_hash, var_timestamp: Helper.es_time(first_timestamp)},
                                     upsert: body
                                 }
    )
    get(occurrence.uber_key)
  end

  def self.forget_old_exceptions(project, days=0)
    since_date = Time.now - (86400 * days)
    deleted = 0

    exceptions = find(filters: [{ term: { project_name: project } }, range: { 'last_occurrence.occurred_at' => { lte: Helper.es_time(since_date) } }])

    exceptions.each do |exception|
      exception.forget!
      deleted += 1
    end

    deleted
  end

  def forget!
    Occurrence.delete_all_for(id)

    Exceptionist.esclient.delete(type: ES_TYPE, id: id)
  end

  def close!
    Exceptionist.esclient.update(type: ES_TYPE, id: @id, body: { doc: { closed: true } })
  end

  def update(doc)
    Exceptionist.esclient.update(type: ES_TYPE, id: @id, body: { doc: doc })
  end

  def current_occurrence(position)
    occurrences = Occurrence.find(filters: { term: { uber_key: id } }, sort: { occurred_at: { order: 'asc'} }, from: position - 1, size: 1)
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
    Occurrence.count(filters: [{ term: { uber_key: @id } }, { range: { occurred_at: Helper.day_range(date) } }])
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
