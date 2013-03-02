require 'boot'
require './config'

module Exceptionist
  class IndexCreator
    def self.run
      Exceptionist.mongo['exceptions'].ensure_index(:project_name)

      Exceptionist.mongo['occurrences'].ensure_index(:uber_key)
      Exceptionist.mongo['occurrences'].ensure_index([[:project_name, Mongo::ASCENDING], [:occurred_at_day, Mongo::ASCENDING]])
      Exceptionist.mongo['occurrences'].ensure_index([[:uber_key, Mongo::ASCENDING], [:occurred_at, Mongo::ASCENDING]])
      Exceptionist.mongo['occurrences'].ensure_index([[:uber_key, Mongo::ASCENDING], [:occurred_at_day, Mongo::ASCENDING]])
    end
  end
end
