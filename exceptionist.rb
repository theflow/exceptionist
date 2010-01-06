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
  @title = 'All Projects'
  erb :dashboard
end

get '/projects/:project' do
  @current_project = Project.new(params[:project])
  @start = params[:start] ? params[:start].to_i : 0
  @uber_exceptions = @current_project.latest_exceptions(@start)

  @title = "Latest Exceptions for #{@current_project.name}"
  erb :index
end

get '/exceptions/:id' do
  @uber_exception = UberException.new(params[:id])
  if params[:occurrence_id]
    @occurrence = Occurrence.find(params[:occurrence_id])
  else
    @occurrence = @uber_exception.last_occurrence
  end
  @current_project = @occurrence.project
  erb :show
end

post '/occurrences/:id' do
  @occurrence = Occurrence.find(params[:id])
  @occurrence.close!

  redirect "/projects/#{@occurrence.project_name}"
end

post '/notifier_api/v2/notices/' do
  occurrence = Occurrence.from_xml(request.body.read)
  occurrence.save
  UberException.occurred(occurrence)
end

before do
  @projects = Project.all if request.get?
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
