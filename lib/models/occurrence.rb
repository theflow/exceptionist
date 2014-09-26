class Occurrence

  attr_accessor :url, :controller_name, :action_name,
                :exception_class, :exception_message, :exception_backtrace,
                :parameters, :session, :cgi_data, :environment,
                :project_name, :occurred_at, :id, :uber_key, :api_key, :sort,
                :ip_address, :request_id

  ES_TYPE = 'occurrences'

  def initialize(attributes = {})
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    @occurred_at = Time.parse(occurred_at) if occurred_at.is_a? String
    @uber_key ||= generate_uber_key
  end

  def uber_exception
    UberException.get(uber_key)
  end

  def self.delete_all_for(uber_key)
    Exceptionist.esclient.delete_by_query(query: { term: { uber_key: uber_key } })
  end

  def self.find_first_for(uber_key)
    occurrences = Occurrence.find(filters: { term: { uber_key: uber_key } }, sort: { occurred_at: { order: 'asc' } }, size: 1)
    occurrences.any? ? occurrences.first : nil
  end

  def self.find_last_for(uber_key)
    occurrences = Occurrence.find(filters: { term: { uber_key: uber_key } }, size: 1)
    occurrences.any? ? occurrences.first : nil
  end

  def self.find_next(uber_key, date)
    find(filters: [{ range: { occurred_at: { gte: Helper.es_time(date) } } },
                   { term: { uber_key: uber_key } }], sort: { occurred_at: { order: 'asc' } }, size: 1).first
  end

  def self.find(filters: {}, sort: { occurred_at: { order: 'desc' } }, from: 0, size: 25)
    hash = Exceptionist.esclient.search(type: ES_TYPE, filters: filters, sort: sort, from: from, size: size)
    hash.hits.hits.map { |doc| new(Helper.transform(doc)) }
  end

  def self.count_since(uber_key, date)
    count(filters: [{ range: { occurred_at: { gte: Helper.es_time(date) } } }, { term: { uber_key: uber_key } }] )
  end

  def self.count(filters: {})
    Exceptionist.esclient.count(type: ES_TYPE, filters: filters)
  end

  def self.aggregation(filters: {}, aggregation: '')
    Exceptionist.esclient.aggregation(type: ES_TYPE, filters: filters, aggregation: aggregation)
  end

  #
  # accessors
  #

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

  def project
    Project.new(project_name)
  end

  #
  # serialization
  #

  def save
    occurrence = Exceptionist.esclient.index(type: ES_TYPE, body: create_es_hash)
    @id = occurrence._id
    self
  end

  def create_es_hash
    self.instance_variables.each_with_object({}) do |var, hash|
      value = self.instance_variable_get(var);
      value = Helper.es_time(value) if value.is_a?(Time)
      hash[var.to_s.delete("@")] = value
    end
  end

  def self.from_xml(xml_text)
    attr = parse_xml(xml_text)
    attr['occurred_at'] = Time.now if attr['occurred_at'].nil?

    new(attr)
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

      if hash[:cgi_data]
        hash[:request_id] = hash[:cgi_data]["HTTP_X_PODIO_REQUEST_ID"]
        hash[:ip_address] = hash[:cgi_data]["HTTP_X_FORWARDED_FOR"]
      end
    end

    hash
  end

  def self.parse_vars(node, options = {})
    node.children.inject({}) do |hash, child|
      key = child['key']
      value = node_to_hash(child, options) unless (options[:skip_internal] && key.include?('.'))
      hash[key] = value unless value.nil?
      hash
    end
  end

  def self.node_to_hash(node, options = {})
    if node.children.size > 1
      node.children.inject({}) do |hash, child|
        key = child['key']
        hash[key] = node_to_hash(child, options) unless (options[:skip_internal] && key.include?('.'))
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

  def ==(other)
    id == other.id
  end

  def inspect
    "(Occurrence id=#{id} uber_key=#{uber_key})"
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
