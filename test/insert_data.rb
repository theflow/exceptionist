require './lib/es_client'

esclient = ESClient.new("localhost:9200")

# create database
begin
  esclient.delete_indices('exceptionist')
rescue Elasticsearch::Transport::Transport::Errors::NotFound
end

esclient.create_indices('exceptionist',
                                     { mappings: {
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
                                     } })
esclient.refresh

5.times { `curl -X POST -d @test/fixtures/full_exception.xml http://localhost:9292/notifier_api/v2/notices/?` }

esclient.refresh

