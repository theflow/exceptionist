module Exceptionist
  class UberException < Model
    attr_accessor :id

    def initialize(id)
      @id = id
    end

    # TODO: should move these to a Project class
    def self.count_all(project)
      redis.set_count("Exceptionist::UberExceptions:#{project}")
    end

    def self.find_all(project)
      redis.set_members("Exceptionist::UberExceptions:#{project}").map { |id| new(id) }
    end

    def self.find_all_sorted_by_time(project, page = 1, per_page = 25)
      offset = (page - 1) * per_page
      redis.sort("Exceptionist::UberExceptions:#{project}",
        :by => "Exceptionist::UberExceptions:ByTime:*",
        :order => 'DESC',
        :limit => [offset, per_page]).map { |id| new(id) }
    rescue RuntimeError
      []
    end

    def self.find_all_sorted_by_count(project)
      redis.sort("Exceptionist::UberExceptions:#{project}", :by => "Exceptionist::UberExceptions:ByCount:*", :order => 'DESC').map { |id| new(id) }
    end

    def self.occurred(occurrence)
      # every uber exception has a list of occurrences
      redis.push_tail("Exceptionist::UberException:#{occurrence.uber_key}", occurrence.id)

      # store the timestamp of the last occurrance to be able to sort by that
      redis.set("Exceptionist::UberExceptions:ByTime:#{occurrence.uber_key}", occurrence.occurred_at.to_i)
      # store the occurrence count to be able to sort by that
      redis.incr("Exceptionist::UberExceptions:ByCount:#{occurrence.uber_key}")

      # store a list of exceptions per project
      redis.set_add("Exceptionist::UberExceptions:#{occurrence.project}", occurrence.uber_key)

      # store a top level set of projects
      redis.set_add("Exceptionist::Projects", occurrence.project)
    end

    def last_occurrence
      @last_occurrence ||= Occurrence.find(redis.list_range(key(id), -1, -1))
    end

    def first_occurrence
      @first_occurrence ||= Occurrence.find(redis.list_range(key(id), 0, 0))
    end

    def occurrences
      Exceptionist::Occurrence.find_all(redis.list_range(key(id), 0, -1))
    end

    def first_occurred_at
      first_occurrence.occurred_at
    end

    def last_occurred_at
      last_occurrence.occurred_at
    end

    def title
      last_occurrence.title
    end

    def url
      last_occurrence.url
    end

    def occurrences_count
      redis.list_length(key(id))
    end
  end
end
