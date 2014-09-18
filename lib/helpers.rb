module Helpers

  def self.get_day_ago(days)
    today = Time.now
    today - (3600 * 24 * (days - 1)) # `days` days ago
  end

end
