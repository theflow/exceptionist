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


occurrence_keys = Exceptionist.redis.keys("Exceptionist::Occurrence:id:*")

occurrences = occurrence_keys.map do |key|
  id = key.split(':').last
  Occurrence.find(id)
end

File.open('occurrences_export.json', 'w') do |file|
  file.write(Yajl::Encoder.encode(occurrences))
end

