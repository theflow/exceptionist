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
end
