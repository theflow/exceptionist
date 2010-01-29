require 'rubygems'
require 'yajl'
require 'redis'

require 'models/model'
require 'models/project'
require 'models/uber_exception'
require 'models/occurrence'


module Exceptionist
  def self.namespace
    "Exceptionist"
  end

  def self.redis
    return @redis if @redis
    @redis = Redis.new(:host => '127.0.0.1', :port => 6379, :thread_safe => true)
  end
end

occurrences = Yajl::Parser.parse(File.read('occurrences_export.json'))

occurrences.each do |occurrence_hash|
  occurrence_hash.delete('uber_key')
  occurrence = Occurrence.new(occurrence_hash)
  occurrence.save

  UberException.occurred(occurrence)
end
