class ESClient

  attr_accessor :es, :host, :port

  ES_INDEX = 'exceptionist'

  def initialize(endpoint)
    @host, @port = endpoint.split(':')
    @es = Elasticsearch::Client.new(host: endpoint)
  end

  def search(type: '', filters: {}, sort: {}, from: 0, size: 25)
    raise ArgumentError, 'from has to be >= 0' if from < 0

    query = create_search_query(filters, sort, from, size)
    response = @es.search(index: ES_INDEX, type: type, body: query)
    Hashie::Mash.new(response)
  end

  def aggregation(type: '', filters: [], aggregation: '')
    # size set 0 for Integer.MAX_VALUE
    query = { query: wrap_filters(filters), aggs: { exceptions: { terms: { field: aggregation, size: 0 } } } }
    response = @es.search(index: ES_INDEX, type: type, body: query, search_type: 'count')
    hash = Hashie::Mash.new(response)
    hash.aggregations.exceptions.buckets
  end

  def mget(type: '', ids: [])
    response = @es.mget( index: ES_INDEX, type: type, body: { ids: ids } )
    hash = Hashie::Mash.new(response)
    hash.docs
  end

  def index(type: '', body: {})
    response = @es.index(index: ES_INDEX, type: type, body: body)
    Hashie::Mash.new(response)
  end

  def update(type: '', id: -1, body: {})
    @es.update(index: ES_INDEX, type: type, id: id, body: body)
  end

  def count(type: '', filters: [], terms: [])
    terms = wrap(terms)
    filters = wrap(filters)
    terms = transform_terms(terms)
    @es.count(index: ES_INDEX, type: type, body: { query: wrap_filters(terms.push(*filters)) } )['count']
  end

  def delete_by_query(query: { match_all: {} })
    @es.delete_by_query( index: ES_INDEX, body: { query: query } )
  end

  def delete(type: '', id: -1)
    @es.delete(index: ES_INDEX, type: type, id: id)
  end

  def delete_indices(index)
    @es.indices.delete(index: index)
  end

  def create_indices(index, body={})
    @es.indices.create(index: index, body: body)
  end

  def get_mapping(type)
    @es.indices.get_mapping(index: ES_INDEX, type: type)
  end

  def get(type: '', id: id)
    @es.get(index: ES_INDEX, type: type, id: id)
  end

  def refresh
    @es.indices.refresh
  end

  private
  def create_search_query(filters, sort, from, size)
    { query: wrap_filters(filters), sort: wrap_sort(sort), from: from, size: size }
  end

  def wrap_sort(sort)
    wrap(sort).each { | field | add_ignore_unmapped(field) }
  end

  def wrap_filters(filters)
    { filtered: { filter: { bool: { must: wrap(filters) } } } }
  end

  def add_ignore_unmapped(hash)
    hash.each { | field, ordering | ordering[:ignore_unmapped] = true }
  end

  def wrap(args)
    return [] unless args
    args.is_a?(Array) ? args : [args]
  end

  def transform_terms(terms)
    terms = terms.map { |term| { term: term } if term }
    terms.compact
  end
end
