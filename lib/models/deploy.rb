require 'json'

class Deploy
  attr_accessor :id, :project_name, :api_key, :version, :changelog_link, :deploy_time

  def self.find(project)
    Exceptionist.esclient.search_deploys( term: { project_name: project } )
  end

  def self.find_last_deploy(project)
    Exceptionist.esclient.search_deploys( { term: { project_name: project } }, { deploy_time: { order: 'desc' } }, from: 0, size: 1 ).first
  end

  def self.from_json(json)
    attr = symbolize_keys(JSON.parse(json))
    Deploy.new(attr)
  end

  def occurred_at
    deploy_time.is_a?(String) ? Time.parse(deploy_time) : deploy_time
  end

  def initialize(attributes={})
    attributes.each do |key, value|
      send("#{key}=", value)
    end

    self.deploy_time ||= Time.now
    self.deploy_time = Time.parse(self.deploy_time) if self.deploy_time.is_a? String
  end

  def save
    deploy = Exceptionist.esclient.index('deploys', to_hash)
    @id = deploy._id
    self
  end

  def ==(other)
    project_name == other.project_name && version == other.version
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
        deploy_time: deploy_time.is_a?(String) ? deploy_time : deploy_time.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
    }
  end

  def self.symbolize_keys(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end
end
