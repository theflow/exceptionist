module Exceptionist
  def self.mongo
    @mongo
  end

  def self.mongo=(server)
    case server
    when String
      host, port = server.split(':')
      @mongo = Mongo::Connection.new(host, port).db('exceptionist')
    when Mongo::Connection
      @mongo = server
    else
      raise "I don't know what to do with #{server.inspect}"
    end
  end

  def self.config
    @config ||= {}
  end
end
