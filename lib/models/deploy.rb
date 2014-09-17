require 'json'

class Deploy
  attr_accessor :id, :project_name, :api_key, :version, :changelog_link, :occurred_at

  def self.find_by_project(project)
    find( filters: { term: { project_name: project } } )
  end

  def self.find_last_deploy(project)
    find( filters: { term: { project_name: project } }, from: 0, size: 1).first
  end

  def self.find(filters: {}, sort: { occurred_at: { order: 'desc' } }, from: 0, size: 25)
    raise ArgumentError, 'position has to be >= 0' if from < 0
    Exceptionist.esclient.search_deploys( filters: filters, sort: sort, from: from, size: size )
  end
  def self.from_json(json)
    attr = symbolize_keys(JSON.parse(json))
    Deploy.new(attr)
  end

  def initialize(attributes={})
    attributes.each do |key, value|
      send("#{key}=", value)
    end

    self.occurred_at ||= Time.now
    self.occurred_at = Time.parse(self.occurred_at) if self.occurred_at.is_a? String
  end

  def save
    deploy = Exceptionist.esclient.index('deploys', to_hash)
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
  def to_hash
    {
        project_name: project_name,
        api_key: api_key,
        version: version,
        changelog_link: changelog_link,
        occurred_at: occurred_at.is_a?(String) ? occurred_at : occurred_at.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
    }
  end

  def self.symbolize_keys(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end
end
