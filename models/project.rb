module Exceptionist
  class Project
    attr_accessor :name

    def initialize(name)
      self.name = name
    end

    def exceptions_count
      UberException.count_all(name)
    end

    def latest_exceptions
      Exceptionist::UberException.find_all_sorted_by_time(name, 1, 3)
    end

    def self.all
      redis.set_members('Exceptionist::Projects').map { |name| Project.new(name) }
    end
  end
end
