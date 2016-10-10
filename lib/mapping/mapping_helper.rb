class MappingHelper
  def self.get_mapping
    occurrence = YAML.load(File.read('lib/mapping/occurrences.yaml'))
    exception = YAML.load(File.read('lib/mapping/exceptions.yaml'))
    deploy = YAML.load(File.read('lib/mapping/deploys.yaml'))

    exception['properties']['last_occurrence'] = occurrence

    {
      'mappings' => {
        '_default_' => {
          'dynamic' => 'false'},
        'occurrences' => occurrence,
        'exceptions' => exception,
        'deploys' => deploy
      }
    }
  end
end
