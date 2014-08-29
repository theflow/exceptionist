require 'elasticsearch/extensions/test/cluster'
require 'elasticsearch'

module ElasticSearchHelper
  def self.start(port)
    Elasticsearch::Extensions::Test::Cluster.start(
        cluster_name: "my-testing-cluster",
        port: port,
        nodes: 1,
    )

    begin
      Exceptionist.esclient.delete_indices('exceptionist')
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
    end

    Exceptionist.esclient.create_indices('exceptionist',{ mappings: {
                                            occurrences: { properties: {
                                                action_name: { type: 'string', index: 'not_analyzed' },
                                                controller_name: { type: 'string', index: 'not_analyzed' },
                                                project_name: { type: 'string', index: 'not_analyzed' },
                                                uber_key: { type: 'string', index: 'not_analyzed' },
                                                exception_class: { type: 'string', index: 'not_analyzed' },
                                            } },
                                            exceptions:{ properties: {
                                                project_name: { type: 'string', index: 'not_analyzed' },
                                            } }
                                        } } )
    Exceptionist.esclient.refresh

  end

  def self.stop(port)
    Elasticsearch::Extensions::Test::Cluster.stop(port: port)
  end
end
