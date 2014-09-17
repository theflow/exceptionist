require 'elasticsearch/extensions/test/cluster'
require 'elasticsearch'

module ESHelper

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
end
