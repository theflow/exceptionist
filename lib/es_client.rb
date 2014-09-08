require 'elasticsearch'

class ESClient
  attr_accessor :es
  INDEX = 'exceptionist'
  TYPE_EXCEPTIONS = 'exceptions'
  TYPE_OCCURRENCES = 'occurrences'

  def initialize(endpoint)
    @es = Elasticsearch::Client.new(host: endpoint)
  end

  def search_occurrences(filters, sort={}, from=0, size=50)
    query = create_search_query(filters, sort, from, size)
    response = @es.search(index: INDEX, type: TYPE_OCCURRENCES, body: query)
    hash = Hashie::Mash.new(response)
    hash.hits.hits.map { |doc| create_occurrence(doc) }
  end

  def search_exceptions(filters, sort={}, from=0, size=50)
    query = create_search_query(filters, sort, from, size)
    response = @es.search(index: INDEX, type: TYPE_EXCEPTIONS, body: query)
    hash = Hashie::Mash.new(response)
    hash.hits.hits.map { |doc| create_exception(doc) }
  end

  def search_aggs(filters, aggs)
    query = { query: { filtered: { filter: { bool: { must: filters } } } }, aggs: { exceptions: { terms: { field: aggs } } } }
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

  def count(type, terms)
    terms = [terms] if terms.class == Hash
    query = { query: { filtered: { filter: { bool: { must: terms } } } } }

    @es.count(index: INDEX, type: type, body: query)['count']
  end

  def delete_by_query(query)
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
  def create_occurrence(attributes)
    return nil unless attributes

    attributes.merge!(attributes['_source']).delete('_source')
    Occurrence.new(attributes)
  end

  def create_exception(attributes)
    attributes.merge!(attributes['_source']).delete('_source')
    UberException.new(attributes)
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