module Helper

  def self.get_day_ago(days)
    today = Time.now
    today - (3600 * 24 * (days - 1)) # `days` days ago
  end

  def self.last_n_days(days)
    start = Helper.get_day_ago(days)
    today = Time.now

    n_days = []
    begin
      n_days << Time.utc(start.year, start.month, start.day)
    end while (start += 86400) <= today

    n_days
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