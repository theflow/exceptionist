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
      Exceptionist.endpoint = 'localhost:9200'

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
      Net::HTTP.start('exceptionist.nextpodio.dk', 6000) do |http|
        request = Net::HTTP::Post.new('/notifier_api/v2/deploy/?')
        request.body = JSON.generate({
                                         'project_name'        => 'project',
                                         'api_key'             => 'api_key',
                                         'changelog_link'      => 'changes',
                                         'version'             => 'version',

                                     })
        puts response = http.request(request)
      end
    end
  end
end
