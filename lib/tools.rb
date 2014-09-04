require 'boot'
require './config'

module Exceptionist
  class Remover
    def self.run(uber_key)
      UberException.find(uber_key).forget!
    end
  end

  class Exporter
    def self.run
      occurrences = Occurrence.find_all(nil, 10000).map { |occurrence| occurrence.to_hash }

      File.open('occurrences_export.json', 'w') do |file|
        file.write(Yajl::Encoder.encode(occurrences))
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
end
