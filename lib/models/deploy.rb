class Deploy < AbstractModel

  attr_accessor :id, :project_name, :api_key, :version, :changelog_link, :occurred_at

  TYPE_DEPLOYS = 'deploys'

  def initialize(attributes={})
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    @occurred_at = Time.parse(self.occurred_at) if self.occurred_at.is_a? String
  end

  def self.find_by_project_since(project, date)
    find( filters: [ { term: { project_name: project } }, { range: { occurred_at: { gte: Helper.es_time(date) } } } ] )
  end

  def self.find_by_project(project)
    find( filters: { term: { project_name: project } } )
  end

  def self.find_last_deploy(project)
    find( filters: { term: { project_name: project } }, from: 0, size: 1).first
  end

  def self.find(filters: {}, sort: { occurred_at: { order: 'desc' } }, from: 0, size: 25)
    hash = Exceptionist.esclient.search(type: TYPE_DEPLOYS, filters: filters, sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| new(Helper.transform(doc)) }
  end

  def self.from_json(json)
    attr = Helper.symbolize_keys(JSON.parse(json))
    attr['occurred_at'] = Time.now if attr['occurred_at'].nil?

    new(attr)
  end

  def save
    deploy = Exceptionist.esclient.index(type: TYPE_DEPLOYS, body: to_hash)
    @id = deploy._id
    self
  end

  def ==(other)
    id == other.id
  end

  def inspect
    "(Deploy id=#{id} project_name=#{project_name})"
  end
end
