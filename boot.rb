require 'rubygems'

require 'redis'
require 'zlib'
require 'yajl'

require 'models/model'
require 'models/project'
require 'models/uber_exception'
require 'models/occurrence'


module Exceptionist
  def self.namespace
    "Exceptionist"
  end

  def self.redis
    @redis ||= initialize_redis
  end

  def self.initialize_redis
    config = YAML.load_file(File.join(File.dirname(__FILE__), 'redis.yml'))
    if config.is_a?(String)
      host, port = config.split(':')
      Redis.new(:host => host, :port => port, :thread_safe => true)
    else
      raise 'Valid redis.yml missing'
    end
  end

  def self.filter
    @filter ||= FilterStore.new
  end

  def self.redis=(redis)
    @redis = redis
  end

  class FilterStore
    def initialize
      @filters = []
    end

    def add(name, &block)
      @filters << [name, block]
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
