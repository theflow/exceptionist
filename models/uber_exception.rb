module Exceptionist
  class UberException < Model
    attr_accessor :id

    def initialize(id)
      @id = id
    end

    def self.find_all
      redis.set_members('Exceptionist::UberExceptions').map { |id| new(id) }
    end

    def self.find_all_sorted_by_time(page = 1)
      offset = (page - 1) * 25
      redis.sort('Exceptionist::UberExceptions',
        :by => "Exceptionist::UberExceptions:ByTime:*",
        :order => 'DESC',
        :limit => [offset, 25]).map { |id| new(id) }
    rescue RuntimeError
      []
    end

    def self.find_all_sorted_by_count
      redis.sort('Exceptionist::UberExceptions', :by => "Exceptionist::UberExceptions:ByCount:*", :order => 'DESC').map { |id| new(id) }
    end

    def self.occurred(occurence)
      redis.push_tail("Exceptionist::UberException:#{occurence.uber_key}", occurence.id)
      redis.set("Exceptionist::UberExceptions:ByTime:#{occurence.uber_key}", occurence.occurred_at.to_i)
      redis.incr("Exceptionist::UberExceptions:ByCount:#{occurence.uber_key}")

      # store a list of exceptions per project
      redis.set_add('Exceptionist::UberExceptions', occurence.uber_key)
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
