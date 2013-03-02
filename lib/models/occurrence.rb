class Occurrence
  attr_accessor :url, :controller_name, :action_name,
                :exception_class, :exception_message, :exception_backtrace,
                :parameters, :session, :cgi_data, :environment,
                :project_name, :occurred_at, :id, :uber_key


  def initialize(attributes = {})
    attributes.each do |key, value|
      send "#{key}=", value
    end

    self.occurred_at ||= attributes['occurred_at'] || Time.now
    self.uber_key ||= generate_uber_key
  end

  def inspect
    "(Occurrence: id: #{id}, title: '#{title}')"
  end

  def ==(other)
    id == other.id
  end

  def title
    case exception_class
      when 'Mysql::Error', 'RuntimeError', 'Timeout::Error', 'SystemExit'
        exception_message
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
    UberException.new(uber_key)
  end

  def close!
    # do this here, because the UberException does not know which project it's in
    redis.zrem("Exceptionist::Project:#{project_name}:UberExceptions", uber_key)
  end

  def self.find(id)
    unserialize redis.get(key(id))
  end

  def self.find_all(ids)
    ids = ids.map { |id| key(id) }
    keys = redis.mget(*ids)
    keys.map { |key| unserialize(key) }
  end

  def self.count_new_on(project, day)
    redis.llen("Exceptionist::Project:#{project}:OnDay:#{day.strftime('%Y-%m-%d')}")
  end

  #
  # serialization
  #

  def save
    self.id = generate_id
    redis.set(key(self.id), serialize)

    self
  end

  def self.create(attributes = {})
    new(attributes).save
  end

  def to_hash
    { :exception_message   => exception_message,
      :session             => session,
      :action_name         => action_name,
      :parameters          => parameters,
      :cgi_data            => cgi_data,
      :url                 => url,
      :occurred_at         => occurred_at,
      :exception_backtrace => exception_backtrace,
      :controller_name     => controller_name,
      :environment         => environment,
      :exception_class     => exception_class,
      :project_name        => project_name,
      :id                  => id,
      :uber_key            => uber_key }
  end

  def serialize
    Zlib::Deflate.deflate(to_json)
  end

  def to_json
    Yajl::Encoder.encode(to_hash)
  end

  def self.unserialize(data)
    from_json(Zlib::Inflate.inflate(data))
  end

  def self.from_json(json)
    new(Yajl::Parser.parse(json))
  end

  def self.from_xml(xml_text)
    new(parse_xml(xml_text))
  end

  def self.parse_xml(xml_text)
    doc = Nokogiri::XML(xml_text) { |config| config.noblanks }

    hash = {}
    hash[:project_name] = doc.xpath('/notice/api-key').first.content
    hash[:environment]  = doc.xpath('/notice/server-environment/environment-name').first.content

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
      hash[:cgi_data] = parse_vars(doc.xpath('/notice/request/cgi-data'), :skip_rack => true)
    end

    hash
  end

  def self.parse_vars(node, options = {})
    node.children.inject({}) do |hash, child|
      key = child['key']
      hash[key] = self.node_to_hash(child, options)
      hash
    end
  end

  def self.node_to_hash(node, options = {})
    if node.children.size > 1
      node.children.inject({}) do |hash, child|
        key = child['key']
        hash[key] = self.node_to_hash(child, options)
        hash
      end
    elsif node.children.size == 1 && node.children.first.keys.include?("key")
      { node.children.first["key"] => node.content }
    else
      node.content unless (options[:skip_rack] && node['key'].include?('.'))
    end
  end

  def self.parse_optional_element(doc, xpath)
    element = doc.xpath(xpath).first
    element ? element.content : nil
  end

  def self.key(*parts)
    "#{Exceptionist.namespace}::#{name}:#{parts.join(':')}"
  end

private

  def generate_id
    redis.incr("Exceptionist::OccurrenceIdGenerator")
  end

  def generate_uber_key
    key = case exception_class
      when 'Mysql::Error', 'RuntimeError', 'SystemExit'
        "#{exception_class}:#{exception_message}"
      when 'Timeout::Error'
        first_non_lib_line = exception_backtrace.detect { |line| line =~ /\[PROJECT_ROOT\]/ }
        "#{exception_class}:#{exception_message}:#{first_non_lib_line}"
      else
        backtrace = exception_backtrace ? exception_backtrace.first : ''
        "#{controller_name}:#{action_name}:#{exception_class}:#{backtrace}"
    end

    Digest::SHA1.hexdigest("#{project_name}:#{key}")
  end

  def key(*parts)
    self.class.key(*parts)
  end

  def redis
    Exceptionist.redis
  end

  def self.redis
    Exceptionist.redis
  end
end
