module Exceptionist
  class Model
    attr_accessor :id

    def initialize(attributes = {})
      attributes.each do |key, value|
        send "#{key}=", value
      end
    end

    def save
      self.id = generate_id unless @id
      redis.set(key(:id, send(:id)), to_json)

      self
    end

    def generate_id
      redis.incr key(:id)
    end

    def key(*parts)
      self.class.key(*parts)
    end

    def self.key(*parts)
      "#{Exceptionist.namespace}::#{name}:#{parts.join(':')}"
    end

    def self.find(id)
      from_json redis.get(key(:id, id))
    end

    def self.find_all(ids)
      ids.map { |id| find(id) }
    end

    #
    # serialization
    #

    def self.from_json(json)
      new(Yajl::Parser.parse(json))
    end

    def to_hash
      {}
    end

    def to_json
      Yajl::Encoder.encode(to_hash)
    end

    def self.redis
      Exceptionist.redis
    end

    def redis
      Exceptionist.redis
    end
  end
end
