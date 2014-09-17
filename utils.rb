require 'elasticsearch/extensions/test/cluster'
require 'elasticsearch'
require 'boot'


module Utils

  class Exporter
    def self.run
      occurrences = Occurrence.find.map { |occurrence| occurrence.to_hash }

      File.open('occurrences_export.json', 'w') do |file|
        file.write(Yajl::Encoder.encode(occurrences))
      end
    end
  end

  class Importer
    def self.run
      Exceptionist.endpoint = 'localhost:9200'

      puts "importing deploy.yaml"
      YAML.load(File.read('import/deploy.yaml')).each { |key, value| Deploy.new(value).save}

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

      Exceptionist.esclient.create_indices('exceptionist',YAML.load(File.read('lib/mapping.yaml')))
      Exceptionist.esclient.refresh
    end
  end

  class Mapping
    def self.run
      pp Exceptionist.esclient.get_mapping('occurrences')
      puts
      pp Exceptionist.esclient.get_mapping('exceptions')
    end
  end
end
