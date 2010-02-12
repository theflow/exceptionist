require 'boot'

module Exceptionist
  class Exporter
    def self.run
      occurrence_keys = Exceptionist.redis.keys("Exceptionist::Occurrence:id:*")

      occurrences = occurrence_keys.map do |key|
        id = key.split(':').last
        Occurrence.find(id)
      end

      File.open('occurrences_export.json', 'w') do |file|
        file.write(Yajl::Encoder.encode(occurrences))
      end
    end
  end

  class Importer
    def self.run
      occurrences = Yajl::Parser.parse(File.read('occurrences_export.json'))

      occurrences.each do |occurrence_hash|
        occurrence_hash.delete('uber_key')
        occurrence = Occurrence.new(occurrence_hash)
        occurrence.save

        UberException.occurred(occurrence)
      end
    end
  end

  class Migrator
  end
end
