require 'boot'

require 'sinatra'
require 'net/smtp'
require 'stringio'
require 'pp'


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

  body = <<MESSAGE_END
From: The Exceptionst <the@exceptionist.com>
To: The Exceptionst <the@exceptionist.com>
MIME-Version: 1.0
Content-type: text/html
Subject: [Exceptionist][#{@current_project.name}] Summary for #{params[:day]}

#{message_body}
MESSAGE_END

  account = Exceptionist.config[:smtp_settings]
  Net::SMTP.start(account[:host], account[:port], 'localhost', account[:user], account[:pass], account[:auth]) do |smtp|
    smtp.send_message(body, 'the@exceptionist.com', 'surf@theflow.de')
  end

  message_body
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

  redirect "/projects/#{@occurrence.project_name}"
end

post '/notifier_api/v2/notices/' do
  occurrence = Occurrence.from_xml(request.body.read)
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
