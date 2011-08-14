require 'boot'
require 'config'

module Exceptionist
  class Exporter
    def self.run
      occurrence_keys = Exceptionist.redis.keys("Exceptionist::Occurrence:*")

      # # only the last 2000, for testing
      # last_id = Exceptionist.redis.get('Exceptionist::OccurrenceIdGenerator').to_i
      # occurrence_keys = ((last_id - 2000)..last_id).to_a.map { |id| "Exceptionist::Occurrence:#{id}" }

      key_groups = []
      occurrence_keys.each_slice(10000) { |group| key_groups << group }

      key_groups.each_with_index do |keys, i|
        puts "exporting #{i} of #{key_groups.size - 1}"

        occurrences = keys.map do |key|
          id = key.split(':').last
          Occurrence.find(id)
        end

        File.open("occurrences_export_#{i}.json", 'w') do |file|
          file.write(Yajl::Encoder.encode(occurrences))
        end

        occurrences = nil
      end
    end
  end

  class Importer
    def self.run
      files = Dir.glob('occurrences_export*').sort
      files.each do |file|
        puts "importing #{file}"

        occurrences = Yajl::Parser.parse(File.read(file))
        occurrences.each do |occurrence_hash|
          occurrence_hash.delete('uber_key')
          occurrence_hash.delete('id')
          occurrence = Occurrence.new(occurrence_hash)
          occurrence.save

          UberException.occurred(occurrence)
        end
      end
    end
  end

  class Reseter
    def self.run
      all_keys = Exceptionist.redis.keys("Exceptionist::*")
      all_keys.each { |key| Exceptionist.redis.del(key) }
    end
  end

  class Migrator
  end

  class IndexCreator
    def self.run
      Exceptionist.mongo['occurrences'].ensure_index([[:occurred_at_day, Mongo::ASCENDING], [:project_name, Mongo::ASCENDING]])
      Exceptionist.mongo['occurrences'].ensure_index(:uber_key)
    end
  end
end
