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
  @uber_exceptions = Exceptionist::UberException.find_all_sorted_by_time

  @title = 'Dashboard'
  erb :dashboard
end

get '/exceptions/:id' do
  @uber_exception = Exceptionist::UberException.new(params[:id])
  @occurrence = @uber_exception.last_occurrence
  erb :show
end

helpers do
  def format_time(time)
    time.strftime('%b %d %H:%M')
  end
end
