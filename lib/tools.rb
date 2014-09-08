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

          # TODO: still problems with es mapping when indexing new documents
          replace_empty_deep!(occurrence_hash)
          occurrence_hash.delete('uber_key')
          occurrence_hash.delete('id')
          occurrence_hash['parameters'].delete('utm_source') if occurrence_hash['parameters']
          occurrence_hash['parameters'].delete('status') if occurrence_hash['parameters']

          occurrence = Occurrence.new(occurrence_hash)
          occurrence.save

          UberException.occurred(occurrence)
        end
      end
    end

    def self.replace_empty_deep!(h)
      h.each do | k, v |
        if  v && v.empty?
          h[k] = nil
        else
          replace_empty_deep!(v) if v.kind_of?(Hash)
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
      Exceptionist.esclient.refresh
    end
  end
end
