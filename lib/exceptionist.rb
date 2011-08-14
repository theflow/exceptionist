module Exceptionist
  def self.mongo
    @mongo ||= Mongo::Connection.new(@host, @port).db('exceptionist')
  end

  def self.mongo=(server)
    @host, @port = server.split(':')
  end

  def self.config
    @config ||= {}
  end

  def self.projects
    @projects ||= ActiveSupport::OrderedHash.new
  end

  def self.add_project(name, api_key)
    projects[name] = api_key
  end
end
