require 'rubygems'

require 'sinatra'

require 'redis'
require 'zlib'
require 'yajl'

require 'models/model'
require 'models/uber_exception'
require 'models/occurrence'

module Exceptionist
  def self.redis
    return @redis if @redis
    @redis = Redis.new(:host => '127.0.0.1', :port => 6379, :thread_safe => true)
  end

  def self.redis=(redis)
    @redis = redis
  end

  def self.encode(object)
    Zlib::Deflate.deflate Yajl::Encoder.encode(object)
  end

  def self.decode(object)
    Yajl::Parser.parse(Zlib::Inflate.inflate(object)) rescue nil
  end
end

def redis
  Exceptionist.redis
end

get '/' do
  @page = params[:page] ? params[:page].to_i : 1
  @uber_exceptions = Exceptionist::UberException.find_all_sorted_by_time(@page)

  @title = 'Dashboard'
  erb :dashboard
end

get '/exceptions/:id' do
  @uber_exception = Exceptionist::UberException.new(params[:id])
  if params[:occurrence_id]
    @occurrence = Exceptionist::Occurrence.find(params[:occurrence_id])
  else
    @occurrence = @uber_exception.last_occurrence
  end
  erb :show
end

post '/notifier_api/v2/notices/' do
  occurrence = Exceptionist::Occurrence.from_xml(request.body.read)
  occurrence.save
  Exceptionist::UberException.occurred(occurrence)
end

helpers do
  def format_time(time)
    time.strftime('%b %d %H:%M')
  end

  def truncate(text, length)
    return if text.nil?
    (text.length > length ? text[0...length] + '...' : text).to_s
  end
end
