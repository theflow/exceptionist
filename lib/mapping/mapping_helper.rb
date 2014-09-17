class MappingHelper
  def self.get_mapping
    occur = YAML.load(File.read('lib/mapping/occurrences.yaml'))
    exce = YAML.load(File.read('lib/mapping/exceptions.yaml'))
    deploy = YAML.load(File.read('lib/mapping/deploys.yaml'))

    exce['properties']['last_occurrence'] = occur

    {
      'mappings' => {
        '_default_' => {
          'dynamic' => 'false'},
        'occurrences' => occur,
        'exceptions' => exce,
        'deploys' => deploy
      }
    }
  end
end
