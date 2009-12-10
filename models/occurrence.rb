require 'digest'
require 'nokogiri'

module Exceptionist
  class Occurrence < Model
    attr_accessor :exception_message, :session, :action_name,
                  :parameters, :url, :occurred_at, :exception_backtrace,
                  :controller_name, :environment, :exception_class,
                  :framework, :language, :application_root, :id, :uber_key

    def title
      "#{exception_class} in #{controller_name}##{action_name}"
    end

    def occurred_at
      @occurred_at.is_a?(String) ? DateTime.parse(@occurred_at) : @occurred_at
    end

    def to_hash
      { :exception_message   => exception_message,
        :session             => session,
        :action_name         => action_name,
        :parameters          => parameters,
        :url                 => url,
        :occurred_at         => occurred_at,
        :exception_backtrace => exception_backtrace,
        :controller_name     => controller_name,
        :environment         => environment,
        :exception_class     => exception_class,
        :id                  => id,
        :uber_key            => uber_key }
    end

    def self.from_xml(xml_text)
      hash = xml_to_hash(xml_text)
      key = Digest::SHA1.hexdigest([:controller_name, :action_name, :exception_class].map { |k| hash[k] }.join(':'))
      new(hash.merge(:occurred_at => Time.now, :uber_key => key))
    end

    def self.xml_to_hash(xml_text)
      doc = Nokogiri::XML(xml_text) { |config| config.noblanks }

      hash = {}
      api_key = doc.xpath('/notice/api-key')
      hash[:environment] = doc.xpath('/notice/server-environment/environment-name').first.content

      hash[:exception_class]     = doc.xpath('/notice/error/class').first.content
      hash[:exception_message]   = doc.xpath('/notice/error/message').first.content
      hash[:exception_backtrace] = doc.xpath('/notice/error/backtrace').children.map do |child|
        "#{child['file']}:#{child['number']}:in `#{child['method']}'"
      end

      hash[:url] = doc.xpath('/notice/request/url').first.content
      hash[:controller_name] = doc.xpath('/notice/request/component').first.content
      hash[:action_name] = doc.xpath('/notice/request/action').first.content

      hash[:parameters]  = parse_vars(doc.xpath('/notice/request/params'))
      hash[:session]     = parse_vars(doc.xpath('/notice/request/session'))
      hash[:environment] = parse_vars(doc.xpath('/notice/request/cgi-data'), :skip_rack => true)

      hash
    end

    def self.parse_vars(node, options = {})
      node.children.inject({}) do |hash, child|
        key = child['key']
        hash[key] = child.content unless (options[:skip_rack] && key.include?('.'))
        hash
      end
    end
  end
end
