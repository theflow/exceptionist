require 'boot'

require 'sinatra/base'
require 'net/smtp'
require 'stringio'
require 'pp'


class ExceptionistApp < Sinatra::Base
  dir = File.join(File.dirname(__FILE__), '..')
  set :views,  "#{dir}/views"
  set :public_folder, "#{dir}/public"

  before do
    protected! if request.path_info !~ /^\/notifier_api\/v2/
  end

  get '/' do
    @projects = Project.all
    @title = 'All Projects'
    @is_dashboard = true
    erb :dashboard
  end

  get '/river' do
    @occurrences = Occurrence.find

    @title = "River"
    erb :river
  end

  get '/projects/:project' do
    @projects = Project.all
    @current_project = Project.new(params[:project])
    @start = params[:start] ? params[:start].to_i : 0
    if params[:sort_by] && params[:sort_by] == 'frequent'
      @uber_exceptions = UberException.find_sorted_by_occurrences_count(@current_project.name, @start)
    else
      @uber_exceptions = UberException.find(project: @current_project.name, from: @start)
    end
    @title = "Latest Exceptions for #{@current_project.name}"
    erb :index
  end

  get '/projects/:project/since_last_deploy' do
    @projects = Project.all
    @current_project = Project.new(params[:project])
    @start = params[:start] ? params[:start].to_i : 0
    if params[:sort_by] && params[:sort_by] == 'frequent'
      @uber_exceptions = UberException.find_since_last_deploy_ordered_by_occurrences_count(@current_project.name)
    else
      @uber_exceptions = UberException.find_since_last_deploy(@current_project.name)
    end
    @title = "Exceptions since last deploy for #{@current_project.name}"
    erb :index
  end

  get '/projects/:project/river' do
    @current_project = Project.new(params[:project])
    @occurrences = Occurrence.find_by_name(@current_project.name)

    @title = "Latest Occurrences for #{@current_project.name}"
    erb :river
  end

  get '/projects/:project/new_on/:day' do
    @day = Time.parse(params[:day])
    @current_project = Project.new(params[:project])
    @uber_exceptions = UberException.find_new_on(@current_project.name, @day)

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
    @uber_exception = UberException.get(params[:id])
    @occurrence_position = @uber_exception.occurrences_count
    @occurrence = @uber_exception.current_occurrence(@occurrence_position)

    if @occurrence.nil?
      @uber_exception.update_occurrences_count
      redirect request.url
    end

    @current_project = @occurrence.project
    @backlink = true

    @title = "[#{@current_project.name}] #{@uber_exception.title}"
    erb :show
  end

  get '/exceptions/:id/occurrences/:occurrence_position' do
    @uber_exception = UberException.get(params[:id])
    @occurrence_position = params[:occurrence_position].to_i
    @occurrence = @uber_exception.current_occurrence(@occurrence_position)

    erb :_occurrence, :layout => false
  end

  post '/exceptions/:id/close' do
    @uber_exceptions = UberException.get(params[:id])
    @uber_exceptions.close!

    redirect to("/projects/#{@uber_exceptions.project_name}?#{Rack::Utils.unescape(params[:backparams])}")
  end

  post '/notifier_api/v2/notices/?' do
    occurrence = Occurrence.from_xml(params[:data] || request.body.read)
    project = Project.find_by_key(occurrence.api_key)

    if project
      occurrence.project_name = project.name
      occurrence.save
      uber_exc = UberException.occurred(occurrence)

      "<notice><id>#{uber_exc.id}</id></notice>"
    else
      status 401
      'Invalid API Key'
    end
  end

  post '/notifier_api/v2/deploy/?' do
    deploy = Deploy.from_json(params[:data] || request.body.read)
    project = Project.find_by_key(deploy.api_key)
    if project
      deploy.project_name = project.name
      deploy.save

      "<notice><id>#{deploy.id}</id></notice>"
    else
      status 401
      'Invalid API Key'
    end
  end

  helpers do
    include Rack::Utils

    def protected!
      return if authorized?

      response['WWW-Authenticate'] = %(Basic realm="Exceptionist")
      throw(:halt, [401, "Not authorized\n"])
    end

    def authorized?
      return true if Exceptionist.credentials.nil?

      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == Exceptionist.credentials
    end

    def format_time(time)
      time.localtime.strftime('%b %d %H:%M')
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
