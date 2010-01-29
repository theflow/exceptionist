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


def add_occurrences_per_day
  occurrence_keys = Exceptionist.redis.keys("Exceptionist::Occurrence:id:*")

  occurrence_keys.each do |key|
    id = key.split(':').last
    occurrence = Occurrence.find(id)

    # store a list of occurrences per project per day
    Exceptionist.redis.push_tail("Exceptionist::Project:#{occurrence.project_name}:OnDay:#{occurrence.occurred_at.strftime('%Y-%m-%d')}", occurrence.id)
  end
end


add_occurrences_per_day