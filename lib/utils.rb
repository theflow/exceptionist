require 'boot'
require 'config'
require 'elasticsearch'


module Utils

  class Exporter
    def self.run

      puts "exporting deploys"
      deploys = Exceptionist.esclient.export('deploys')

      File.open('deploys_export.json', 'w') do |file|
        file.write(Yajl::Encoder.encode(deploys))
      end

      puts "exporting occurrences"
      occurrences = Exceptionist.esclient.export('occurrences')

      File.open('occurrences_export.json', 'w') do |file|
        file.write(Yajl::Encoder.encode(occurrences))
      end
    end
  end

  class Importer
    def self.run
      puts "importing deploys"
      Yajl::Parser.parse(File.read('import/deploys_export.json')).each { |hash| Deploy.new(hash).save}

      files = Dir.glob('import/occurrences_export*').sort
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

  class ClearDB
    def self.run
      begin
        Exceptionist.esclient.delete_indices('exceptionist')
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
      end

      Exceptionist.esclient.create_indices('exceptionist', MappingHelper.get_mapping)
      Exceptionist.esclient.refresh
    end
  end

  class Mapping
    def self.run
      pp Exceptionist.esclient.get_mapping 'deploys'
      pp Exceptionist.esclient.get_mapping 'exceptions'
      pp Exceptionist.esclient.get_mapping 'occurrences'
    end
  end
end
