module Helpers

  def self.get_day_ago(days)
    today = Time.now
    today - (3600 * 24 * (days - 1)) # `days` days ago
  end

  def self.symbolize_keys(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end

  def self.wrap(args)
    return [] unless args
    args.is_a?(Array) ? args : [args]
  end

  def self.es_time(date)
    date.strftime("%Y-%m-%dT%H:%M:%S.%L%z")
  end

  def self.es_day(date)
    date.strftime('%Y-%m-%d')
  end
end
