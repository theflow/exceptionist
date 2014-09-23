module Helpers

  def self.get_day_ago(days)
    today = Time.now
    today - (3600 * 24 * (days - 1)) # `days` days ago
  end

  def self.symbolize_keys(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end
end
