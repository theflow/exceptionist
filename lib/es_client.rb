require 'elasticsearch'

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

  def search_occurrences(filters: {}, sort: {}, from: 0, size: 25)
    hash = search(filters: filters, sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| create_occurrence(doc) }
  end

  def search_exceptions(filters: {}, sort: {}, from: 0, size: 25)
    hash = search(type: TYPE_EXCEPTIONS, filters: filters, sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| create_exception(doc) }
  end

  def search(type: 'occurrences', filters: {}, sort: {}, from: 0, size: 25)
    query = create_search_query(filters, sort, from, size)
    response = @es.search(index: INDEX, type: type, body: query)
    Hashie::Mash.new(response)
  end

  def search_deploys(filters, sort={}, from=0, size=25)
    query = create_search_query(filters, sort, from, size)
    response = @es.search(index: INDEX, type: TYPE_DEPLOYS, body: query)
    hash = Hashie::Mash.new(response)
    hash.hits.hits.map { |doc| create_deploy(doc) }
  end

  def search_aggs(filters, aggs)
    # size set 0 for Integer.MAX_VALUE
    query = { query: { filtered: { filter: { bool: { must: filters } } } }, aggs: { exceptions: { terms: { field: aggs, size: 0 } } } }
    response = @es.search(index: INDEX, type: TYPE_OCCURRENCES, body: query)
    hash = Hashie::Mash.new(response)
    hash.aggregations.exceptions.buckets
  end

  def search_ids(type, ids)
    response = @es.search(index: INDEX, type: type, body: { query: { ids: { values: ids } } } )
    hash = Hashie::Mash.new(response)
    hash.hits.hits.map { |doc| create_exception(doc) }
  end

  def index(type, body)
    response = @es.index(index: INDEX, type: type, body: body)
    Hashie::Mash.new(response)
  end

  def update(type, id, body)
    @es.update(index: INDEX, type: type, id: id, body: body)
  end

  def count(type: 'occurrences', filters: [])
    filters = [filters] if filters.class == Hash
    query = { query: { filtered: { filter: { bool: { must: filters } } } } }

    @es.count(index: INDEX, type: type, body: query)['count']
  end

  def delete_by_query(query: { match_all: {} })
    @es.delete_by_query( index: INDEX, body: { query: query } )
  end

  def delete(type, id)
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
    attr = symbolize_keys(attr)
    attr[:id] = attr.delete :_id
    attr.delete :_index
    attr.delete :_type
    attr.delete :_score
    attr.delete :sort
    attr
  end

  def symbolize_keys(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end

  def create_search_query(terms, sort, from, size)
    sort = wrap_sort(sort) unless sort.empty?
    return { sort: sort, from: from, size: size } if terms.empty?
    { query: { filtered: { filter: { bool: { must: terms } } } }, sort: sort, from: from, size: size}
  end

  def wrap_sort(sort)
    sort = [sort] if sort.class == Hash
    sort.each { | field | add_ignore_unmapped(field) }
  end

  def add_ignore_unmapped(hash)
    hash.each { | field, ordering | ordering[:ignore_unmapped] = true }
  end

end
