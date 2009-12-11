require 'rubygems'
require 'yajl'
require 'digest'
require 'redis'
require 'time'

def redis
  return @redis if @redis
  @redis = Redis.new
end

def next_exception_id
  redis.incr 'global:nextExceptionId'
end

exceptions = File.readlines('exceptional.log').map do |line|
  line =~ /### Exception: (.*)/
  begin
    Yajl::Parser.parse(eval($1))
  rescue Yajl::ParseError
    next
  end
end

exceptions.compact.each do |e|
  next if e['exception_class'] == 'ActionController::UnknownAction'
  next if e['exception_class'] == 'ActionController::RoutingError'

  id = next_exception_id
  key = Digest::SHA1.hexdigest(['controller_name', 'action_name', 'exception_class'].map { |k| e[k] }.join(':'))

  e['cgi_data'] = e.delete('environment')
  e.delete('framework')
  e.delete('application_root')
  e.delete('language')

  # store the exception data
  redis.set("Exceptionist::Occurrence:id:#{id}", Yajl::Encoder.encode(e.merge('id' => id, 'uber_key' => key)))

  # every uber exception has a list of occurences
  redis.push_tail("Exceptionist::UberException:#{key}", id)
  redis.set("Exceptionist::UberExceptions:ByTime:#{key}", Time.parse(e['occurred_at']).to_i)
  redis.incr("Exceptionist::UberExceptions:ByCount:#{key}")

  # store a list of exceptions per project
  redis.set_add('Exceptionist::UberExceptions', key)
end
