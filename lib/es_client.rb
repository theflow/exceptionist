class ESClient

  attr_accessor :es, :host, :port

  INDEX = 'exceptionist'
  TYPE_EXCEPTIONS = 'exceptions'
  TYPE_OCCURRENCES = 'occurrences'
  TYPE_DEPLOYS = 'deploys'

  def initialize(endpoint)
    @host, @port = endpoint.split(':')
    @es = Elasticsearch::Client.new(host: endpoint)
  end

  def search_deploys(filters: {}, sort: {}, from: 0, size: 25)
    hash = search(type: TYPE_DEPLOYS, filters: filters, sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| create_deploy(doc) }
  end

  def search_exceptions(filters: {}, sort: {}, from: 0, size: 25)
    hash = search(type: TYPE_EXCEPTIONS, filters: filters, sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| create_exception(doc) }
  end

  def search_occurrences(filters: {}, sort: {}, from: 0, size: 25)
    hash = search(filters: filters, sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| create_occurrence(doc) }
  end

  def search_aggs(filters, aggs)
    # size set 0 for Integer.MAX_VALUE
    query = { query: wrap_filters(filters), aggs: { exceptions: { terms: { field: aggs, size: 0 } } } }
    response = @es.search(index: INDEX, type: TYPE_OCCURRENCES, body: query, search_type: 'count')
    hash = Hashie::Mash.new(response)
    hash.aggregations.exceptions.buckets
  end

  def search_ids(type: TYPE_EXCEPTIONS, ids: [])
    response = @es.search(index: INDEX, type: type, body: { query: { ids: { values: ids } } } )
    hash = Hashie::Mash.new(response)
    hash.hits.hits.map { |doc| create_exception(doc) }
  end

  def mget(ids: [])
    response = @es.mget( index: INDEX, type: TYPE_EXCEPTIONS, body: { ids: ids } )
    hash = Hashie::Mash.new(response)
    hash.docs.map { |doc| create_exception(doc) }
  end

  def index(type: TYPE_OCCURRENCES, body: {})
    response = @es.index(index: INDEX, type: type, body: body)
    Hashie::Mash.new(response)
  end

  def update(type: TYPE_EXCEPTIONS, id: -1, body: {})
    @es.update(index: INDEX, type: type, id: id, body: body)
  end

  def count(type: TYPE_OCCURRENCES, filters: [])
    @es.count(index: INDEX, type: type, body: { query: wrap_filters(filters) } )['count']
  end

  def delete_by_query(query: { match_all: {} })
    @es.delete_by_query( index: INDEX, body: { query: query } )
  end

  def delete(type: TYPE_EXCEPTIONS, id: -1)
    @es.delete(index: INDEX, type: type, id: id)
  end

  def delete_indices(index)
    @es.indices.delete(index: index)
  end

  def create_indices(index, query={})
    @es.indices.create(index: index, body: query)
  end

  def get_mapping(type)
    @es.indices.get_mapping(index: INDEX, type: type)
  end

  def get_exception(id)
    response = @es.get(index: INDEX, type: TYPE_EXCEPTIONS, id: id)
    create_exception(response)
  end

  def refresh
    @es.indices.refresh
  end

  private
  def search(type: 'occurrences', filters: {}, sort: {}, from: 0, size: 25)
    query = create_search_query(filters, sort, from, size)
    response = @es.search(index: INDEX, type: type, body: query)
    Hashie::Mash.new(response)
  end

  def create_occurrence(attr)
    attr = transform(attr)
    Occurrence.new(attr)
  end

  def create_exception(attr)
    attr = transform(attr)
    UberException.new(attr)
  end

  def create_deploy(attr)
    attr = transform(attr)
    Deploy.new(attr)
  end

  def transform(attr)
    attr.merge!(attr['_source']).delete('_source')
    attr = Helpers.symbolize_keys(attr)
    attr[:id] = attr.delete :_id
    attr
  end

  def create_search_query(filters, sort, from, size)
    { query: wrap_filters(filters), sort: sort, from: from, size: size }
  end

  def wrap_sort(sort)
    Helpers.wrap(sort).each { | field | add_ignore_unmapped(field) }
  end

  def wrap_filters(filters)
    { filtered: { filter: { bool: { must: Helpers.wrap(filters) } } } }
  end

  def add_ignore_unmapped(hash)
    hash.each { | field, ordering | ordering[:ignore_unmapped] = true }
  end

end
