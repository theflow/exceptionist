require 'boot'
require './config'

module Exceptionist
  class Remover
    def self.run(uber_key)
      UberException.find(uber_key).forget!
    end
  end

  class IndexCreator
    def self.run
      Exceptionist.mongo['exceptions'].ensure_index(:project_name)

      Exceptionist.mongo['occurrences'].ensure_index(:uber_key)
      Exceptionist.mongo['occurrences'].ensure_index([[:project_name, Mongo::ASCENDING], [:occurred_at_day, Mongo::ASCENDING]])
      Exceptionist.mongo['occurrences'].ensure_index([[:uber_key, Mongo::ASCENDING], [:occurred_at, Mongo::ASCENDING]])
      Exceptionist.mongo['occurrences'].ensure_index([[:uber_key, Mongo::ASCENDING], [:occurred_at_day, Mongo::ASCENDING]])

      # River view
      Exceptionist.mongo['occurrences'].ensure_index([[:occurred_at, Mongo::DESCENDING]])
    end
  end
end
