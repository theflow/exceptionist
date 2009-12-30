require 'rubygems'

require 'sinatra'

require 'redis'
require 'zlib'
require 'yajl'

require 'models/model'
require 'models/project'
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

  @title = 'All Projects'
  erb :dashboard
end

get '/projects/:project' do
  @page = params[:page] ? params[:page].to_i : 1
  @current_project = params[:project]
  @uber_exceptions = Exceptionist::UberException.find_all_sorted_by_time(@current_project, @page)

  @title = "Latest Exceptions for #{@current_project}"
  erb :index
end

get '/exceptions/:id' do
  @uber_exception = Exceptionist::UberException.new(params[:id])
  if params[:occurrence_id]
    @occurrence = Exceptionist::Occurrence.find(params[:occurrence_id])
  else
    @occurrence = @uber_exception.last_occurrence
  end
  @current_project = @occurrence.project
  erb :show
end

post '/notifier_api/v2/notices/' do
  occurrence = Exceptionist::Occurrence.from_xml(request.body.read)
  occurrence.save
  Exceptionist::UberException.occurred(occurrence)
end

before do
  @projects = Exceptionist::Project.all if request.get?
end

helpers do
  include Rack::Utils

  def format_time(time)
    time.strftime('%b %d %H:%M')
  end

  def truncate(text, length)
    return if text.nil?
    (text.length > length ? text[0...length] + '...' : text).to_s
  end

  def partial(template, local_vars = {})
    @partial = true
    erb("_#{template}".to_sym, {:layout => false}, local_vars)
  ensure
    @partial = false
  end
end
