require 'elasticsearch/extensions/test/cluster'
require 'elasticsearch'

module ESHelper

  def self.startCluster
    Elasticsearch::Extensions::Test::Cluster.start(
        cluster_name: "my-testing-cluster",
        port: Exceptionist.esclient.port,
        nodes: 1,
    )
  end

  def self.stopCluster
    Elasticsearch::Extensions::Test::Cluster.stop( port: Exceptionist.esclient.port )
  end

  class Exporter
    def self.run
      occurrences = Occurrence.find_all.map { |occurrence| occurrence.to_hash }

      File.open('occurrences_export.json', 'w') do |file|
        file.write(Yajl::Encoder.encode(occurrences))
      end
    end
  end

  class Importer
    def self.run
      files = Dir.glob('test/fixtures/occurrences_export*').sort
      files.each do |file|
        puts "importing #{file}"

        occurrences = Yajl::Parser.parse(File.read(file))
        occurrences.each do |occurrence_hash|

          pp occurrence_hash
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

      Exceptionist.esclient.create_indices('exceptionist',
                                           { mappings: {
                                               _default_: {
                                                   dynamic: 'false'
                                               },
                                               occurrences: {
                                                   properties: {
                                                       action_name: { type: 'string', index: 'not_analyzed' },
                                                       controller_name: { type: 'string', index: 'not_analyzed' },
                                                       project_name: { type: 'string', index: 'not_analyzed' },
                                                       uber_key: { type: 'string', index: 'not_analyzed' },
                                                       exception_class: { type: 'string', index: 'not_analyzed' },
                                                       occurred_at_day: { type: 'date' },
                                                       occurred_at: { type: 'date' }
                                                   } },
                                               exceptions:{
                                                   properties: {
                                                       project_name: { type: 'string', index: 'not_analyzed' },
                                                       closed: { type: 'boolean' },
                                                       occurred_at: { type: 'date' }
                                                   } }
                                           } })
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
