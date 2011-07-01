require 'boot'

require 'sinatra/base'
require 'net/smtp'
require 'stringio'
require 'pp'

class ExceptionistApp < Sinatra::Base
  dir = File.join(File.dirname(__FILE__), '..')
  set :views,  "#{dir}/views"
  set :public, "#{dir}/public"

  get '/' do
    @projects = Project.all
    @title = 'All Projects'
    erb :dashboard
  end

  get '/projects/:project' do
    @projects = Project.all
    @current_project = Project.new(params[:project])
    @start = params[:start] ? params[:start].to_i : 0
    @filter = params[:filter] if params[:filter] != ''
    if params[:sort_by] && params[:sort_by] == 'frequent'
      @uber_exceptions = @current_project.most_frequest_exceptions(@filter, @start)
    else
      @uber_exceptions = @current_project.latest_exceptions(@filter, @start)
    end

    @title = "Latest Exceptions for #{@current_project.name}"
    erb :index
  end

  get '/projects/:project/new_on/:day' do
    @day = Time.parse(params[:day])
    @current_project = Project.new(params[:project])
    @uber_exceptions = @current_project.new_exceptions_on(@day)

    message_body = erb(:new_exceptions, :layout => false)

    if params[:mail_to]
      Mailer.deliver_new_exceptions(@current_project, @day, params[:mail_to], message_body)
    end

    message_body
  end

  post '/projects/:project/forget_exceptions' do
    days = params[:days] ? params[:days].to_i : 31
    deleted = UberException.forget_old_exceptions(params[:project], days)

    "Deleted exceptions: #{deleted}"
  end

  get '/exceptions/:id' do
    @projects = Project.all
    @uber_exception = UberException.new(params[:id])
    @occurrence_position = params[:occurrence_position] ? params[:occurrence_position].to_i : @uber_exception.occurrences_count
    @occurrence = @uber_exception.current_occurrence(@occurrence_position)

    @current_project = @occurrence.project
    @backlink = true

    @title = "[#{@current_project.name}] #{@uber_exception.title}"
    erb :show, :layout => !request.xhr?
  end

  post '/occurrences/:id' do
    @occurrence = Occurrence.find(params[:id])
    @occurrence.close!

    redirect "/projects/#{@occurrence.project_name}?#{Rack::Utils.unescape(params[:backparams])}"
  end

  post '/notifier_api/v2/notices/?' do
    occurrence = Occurrence.from_xml(params[:data] || request.body.read)
    occurrence.save
    UberException.occurred(occurrence)
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

    def build_query_args(args = {})
      build_query(request.params.merge(args))
    end

    def link_to_unless(name, url, condition)
      condition ? "<b>#{name}</b>" : "<a href=\"#{url}\">#{name}</a>"
    end

    def partial(template, local_vars = {})
      @partial = true
      erb("_#{template}".to_sym, {:layout => false}, local_vars)
    ensure
      @partial = false
    end
  end
end
