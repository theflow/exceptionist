require 'boot'

module Exceptionist
  class Exporter
    def self.run
      occurrence_keys = Exceptionist.redis.keys("Exceptionist::Occurrence:id:*")

      occurrences = occurrence_keys.map do |key|
        id = key.split(':').last
        Occurrence.find(id)
      end
      occurrences = occurrences.sort_by(&:occurred_at)

      key_groups = []
      occurrences.each_slice(10000) { |group| key_groups << group }
      key_groups.each_with_index do |keys, i|
        puts "exporting #{i}"

        File.open("occurrences_export_#{i}.json", 'w') do |file|
          file.write(Yajl::Encoder.encode(keys))
        end
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
      all_keys.each { |key| Exceptionist.redis.delete(key) }
    end
  end

  class Migrator
  end
end
