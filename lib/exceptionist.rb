require 'hashie'
require 'multi_json'
require 'faraday'
require 'elasticsearch'
require 'elasticsearch/api'
require 'es_client'

module Exceptionist
  attr_accessor :esclient

  def self.esclient
    @esclient ||= ESClient.new(@elasticsearch_host)
  end

  def self.elasticsearch_host=(elasticsearch_host)
    @elasticsearch_host = elasticsearch_host
  end

  def self.config
    @config ||= {}
  end

  def self.credentials
    @credentials
  end

  def self.enable_authentication(username, password)
    @credentials = [username, password]
  end

  def self.projects
    @projects ||= ActiveSupport::OrderedHash.new
  end

  def self.add_project(name, api_key)
    projects[name] = api_key
  end

  def self.global_exception_classes
    ['Mysql::Error', 'RuntimeError', 'SystemExit']
  end

  def self.timeout_exception_classes
    ['Timeout::Error']
  end
end
