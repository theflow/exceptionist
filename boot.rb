require 'rubygems'

require 'time'
require 'zlib'
require 'redis'
require 'yajl'

require 'models/project'
require 'models/uber_exception'
require 'models/occurrence'


module Exceptionist
  def self.namespace
    "Exceptionist"
  end

  def self.redis
    @redis ||= Redis.new(:host => host, :port => port, :thread_safe => true)
  end

  def self.redis=(server)
    case server
    when String
      host, port = server.split(':')
      @redis = Redis.new(:host => host, :port => port, :thread_safe => true)
    when Redis
      @redis = server
    else
      raise "I don't know what to do with #{server.inspect}"
    end
  end

  def self.config
    @config ||= {}
  end

  def self.filter
    @filter ||= FilterStore.new
  end

  class FilterStore
    def initialize
      @filters = []
    end

    def add(name, &block)
      @filters << [name, block]
    end

    def clear
      @filters = []
    end

    def all
      @filters
    end
  end
end


begin
  require 'config'
rescue LoadError
  puts "\n  Valid config.rb missing, please do a:"
  puts "  cp config.rb.example config.rb\n\n"
  exit
end
