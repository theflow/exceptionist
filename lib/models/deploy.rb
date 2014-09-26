class Deploy

  attr_accessor :id, :project_name, :api_key, :version, :changelog_link, :occurred_at

  ES_TYPE = 'deploys'

  def initialize(attributes = {})
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    @occurred_at = Time.parse(occurred_at) if occurred_at.is_a? String
  end

  def self.find_by_project_since(project, date)
    find( filters: [{ term: { project_name: project } }, { range: { occurred_at: { gte: Helper.es_time(date) } } }] )
  end

  def self.find_by_project(project)
    find( filters: { term: { project_name: project } } )
  end

  def self.find_last_deploy(project)
    find( filters: { term: { project_name: project } }, from: 0, size: 1).first
  end

  def self.find(filters: {}, sort: { occurred_at: { order: 'desc' } }, from: 0, size: 25)
    hash = Exceptionist.esclient.search(type: ES_TYPE, filters: filters, sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| new(Helper.transform(doc)) }
  end

  def self.from_json(json)
    attr = Helper.symbolize_keys(JSON.parse(json))
    attr['occurred_at'] = Time.now if attr['occurred_at'].nil?

    new(attr)
  end

  def save
    deploy = Exceptionist.esclient.index(type: ES_TYPE, body: create_es_hash)
    @id = deploy._id
    self
  end

  def ==(other)
    id == other.id
  end

  def inspect
    "(Deploy id=#{id} project_name=#{project_name})"
  end

  private

  def create_es_hash
    self.instance_variables.each_with_object({}) do |var, hash|
      value = self.instance_variable_get(var);
      value = Helper.es_time(value) if value.is_a?(Time)
      hash[var.to_s.delete("@")] = value
    end
  end
end
