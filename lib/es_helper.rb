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
      occurrences = Occurrence.find.map { |occurrence| occurrence.to_hash }

      File.open('occurrences_export.json', 'w') do |file|
        file.write(Yajl::Encoder.encode(occurrences))
      end
    end
  end

  class Importer
    def self.run
      `curl -X POST -H "Content-Type: application/json" -d @test/fixtures/deploy_old.json localhost:9292/notifier_api/v2/deploy/`
      `curl -X POST -H "Content-Type: application/json" -d @test/fixtures/deploy.json localhost:9292/notifier_api/v2/deploy/`

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

      occurr_prop =
          {action_name: { type: 'string', index: 'not_analyzed' },
           controller_name: { type: 'string', index: 'not_analyzed' },
           project_name: { type: 'string', index: 'not_analyzed' },
           uber_key: { type: 'string', index: 'not_analyzed' },
           exception_class: { type: 'string', index: 'not_analyzed' },
           occurred_at_day: { type: 'date' },
           occurred_at: { type: 'date' } }

      Exceptionist.esclient.create_indices('exceptionist',
                                           { mappings: {
                                               _default_: {
                                                   dynamic: 'false'
                                               },
                                               occurrences: { properties: occurr_prop },
                                               exceptions:{
                                                   properties: {
                                                       project_name: { type: 'string', index: 'not_analyzed' },
                                                       closed: { type: 'boolean' },
                                                       last_occurrence: { properties: occurr_prop},
                                                       first_occurred_at: { type: 'date' },
                                                       occurrences_count: {type: 'long'}
                                                   } },
                                               deploys: {
                                                   properties: {
                                                       project_name: { type: 'string', index: 'not_analyzed' },
                                                       version: { type: 'string', index: 'not_analyzed' },
                                                       deploy_time: { type: 'date' },
                                                       changelog_link: { type: 'string', index: 'not_analyzed'}
                                                   } },
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
