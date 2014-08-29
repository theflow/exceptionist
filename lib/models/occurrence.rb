class Occurrence
  attr_accessor :url, :controller_name, :action_name,
                :exception_class, :exception_message, :exception_backtrace,
                :parameters, :session, :cgi_data, :environment,
                :project_name, :occurred_at, :occurred_at_day, :_id, :uber_key, :api_key,
                :_score, :sort


  def initialize(attributes={})
    attributes.each do |key, value|
      send("#{key}=", value) unless ["_index", "_type"].include?(key)
    end

    self.occurred_at ||= attributes['occurred_at'] || Time.now
    self.uber_key ||= generate_uber_key
  end

  def inspect
    "(Occurrence: id: #{_id}, title: '#{title}')"
  end

  def ==(other)
    _id == other._id
  end

  def title
    case exception_class
      when 'Mysql::Error', 'RuntimeError', 'Timeout::Error', 'SystemExit'
        "#{exception_class} #{exception_message}"
      else
        "#{exception_class} in #{controller_name}##{action_name}"
    end
  end

  def http_method
    cgi_data ? cgi_data['REQUEST_METHOD'] : 'GET'
  end

  def referer
    cgi_data ? cgi_data['HTTP_REFERER'] : nil
  end

  def user_agent
    cgi_data ? cgi_data['HTTP_USER_AGENT'] : nil
  end

  def occurred_at
    @occurred_at.is_a?(String) ? Time.parse(@occurred_at) : @occurred_at
  end

  def project
    Project.new(project_name)
  end

  def uber_exception
    UberException.find(uber_key)
  end

  def self.delete_all_for(uber_key)
    Exceptionist.esclient.delete_by_query({ term: { uber_key: uber_key } })
  end

  def self.find_first_for(uber_key)
    occurrences = Exceptionist.esclient.search_occurrences( { term: { uber_key: uber_key } }, { occurred_at: { order: 'asc' } }, from: 0, size: 1 )
    occurrences.first
  end

  def self.find_last_for(uber_key)
    occurrences = Exceptionist.esclient.search_occurrences( { term: { uber_key: uber_key } }, { occurred_at: { order: 'desc' } }, from: 0, size: 1 )
    occurrences.first
  end

  def self.count_all_on(project, day)
    Exceptionist.esclient.count('occurrences', [ { term: { occurred_at_day: day.strftime('%Y-%m-%d') } }, { term: { project_name: project } } ] )
  end

  def self.find_all(size=50)
    Exceptionist.esclient.search_occurrences( {}, { occurred_at: { order: 'desc' } }, 0, size )
  end

  def self.find_all_by_name(project, limit=50)
    Exceptionist.esclient.search_occurrences( { term: { project_name: project } }, { occurred_at: { order: 'desc' } }, from: 0, size: limit )
  end

  #
  # serialization
  #

  def save
    occurrence = Exceptionist.esclient.index('occurrences', to_hash)
    @_id = occurrence._id
    self
  end

  def self.create(attributes = {})
    new(attributes).save
  end

  def self.es_create(attributes)
    return nil unless attributes

    attributes.merge!(attributes['_source']).delete('_source')
    Occurrence.new(attributes)
  end

  def to_hash
    { :exception_message   => exception_message,
      :session             => session,
      :action_name         => action_name,
      :parameters          => parameters,
      :cgi_data            => cgi_data,
      :url                 => url,
      :occurred_at         => occurred_at.strftime("%Y-%m-%dT%H:%M:%S.%L%z"),
      :occurred_at_day     => occurred_at.strftime('%Y-%m-%d'),
      :exception_backtrace => exception_backtrace,
      :controller_name     => controller_name,
      :environment         => environment,
      :exception_class     => exception_class,
      :project_name        => project_name,
      :uber_key            => uber_key }
  end

  def self.from_xml(xml_text)
    new(parse_xml(xml_text))
  end

  def self.parse_xml(xml_text)
    doc = Nokogiri::XML(xml_text) { |config| config.noblanks }

    hash = {}
    hash[:api_key]     = doc.xpath('/notice/api-key').first.content
    hash[:environment] = doc.xpath('/notice/server-environment/environment-name').first.content

    hash[:exception_class]     = doc.xpath('/notice/error/class').first.content
    hash[:exception_message]   = parse_optional_element(doc, '/notice/error/message')
    hash[:exception_backtrace] = doc.xpath('/notice/error/backtrace').children.map do |child|
      "#{child['file']}:#{child['number']}:in `#{child['method']}'"
    end

    if request = doc.xpath('/notice/request').first
      hash[:url]             = request.xpath('url').first.content
      hash[:controller_name] = request.xpath('component').first.content
      hash[:action_name]     = parse_optional_element(request, 'action')

      hash[:parameters]  = parse_vars(doc.xpath('/notice/request/params'))
      hash[:session]     = parse_vars(doc.xpath('/notice/request/session'))
      hash[:cgi_data] = parse_vars(doc.xpath('/notice/request/cgi-data'), :skip_internal => true)
    end

    hash
  end

  def self.parse_vars(node, options = {})
    node.children.inject({}) do |hash, child|
      key = child['key']
      value = self.node_to_hash(child, options) unless (options[:skip_internal] && key.include?('.'))
      hash[key] = value unless value.nil?
      hash
    end
  end

  def self.node_to_hash(node, options = {})
    if node.children.size > 1
      node.children.inject({}) do |hash, child|
        key = child['key']
        hash[key] = self.node_to_hash(child, options) unless (options[:skip_internal] && key.include?('.'))
        hash
      end
    elsif node.children.size == 1 && node.children.first.keys.include?('key')
      key = node.children.first['key']
      {key => node.content} unless (options[:skip_internal] && key.include?('.'))
    else
      node.content
    end
  end

  def self.parse_optional_element(doc, xpath)
    element = doc.xpath(xpath).first
    element ? element.content : nil
  end

private

  def generate_uber_key
    key = case exception_class
      when *Exceptionist.global_exception_classes
        "#{exception_class}:#{exception_message}"
      when *Exceptionist.timeout_exception_classes
        first_non_lib_line = exception_backtrace.detect { |line| line =~ /\[PROJECT_ROOT\]/ }
        "#{exception_class}:#{exception_message}:#{first_non_lib_line}"
      else
        backtrace = exception_backtrace ? exception_backtrace.first : ''
        "#{controller_name}:#{action_name}:#{exception_class}:#{backtrace}"
    end

    Digest::SHA1.hexdigest("#{project_name}:#{key}")
  end
end
