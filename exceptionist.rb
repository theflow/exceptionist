require 'rubygems'
require 'pp'
require 'stringio'

require 'sinatra'

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
  if params[:sort_by] && params[:sort_by] == 'frequent'
    @uber_exceptions = @current_project.most_frequest_exceptions(@start)
  else
    @uber_exceptions = @current_project.latest_exceptions(@start)
  end

  @title = "Latest Exceptions for #{@current_project.name}"
  erb :index
end

get '/exceptions/:id' do
  @uber_exception = UberException.new(params[:id])
  @occurrence_position = params[:occurrence_position] ? params[:occurrence_position].to_i : @uber_exception.occurrences_count
  @occurrence = @uber_exception.current_occurrence(@occurrence_position)

  @current_project = @occurrence.project

  @title = "[#{@current_project.name}] #{@uber_exception.title}"
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

  def pretty_hash(hash)
    s = StringIO.new
    PP.pp(hash, s)
    s.rewind
    s.read
  end

  def partial(template, local_vars = {})
    @partial = true
    erb("_#{template}".to_sym, {:layout => false}, local_vars)
  ensure
    @partial = false
  end
end
