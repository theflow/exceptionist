require 'elasticsearch/extensions/test/cluster'
require 'elasticsearch'

module ESHelper

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
  
end
