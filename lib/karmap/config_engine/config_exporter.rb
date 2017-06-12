require 'karmap/engine'

module Karma::ConfigEngine

  class ConfigExporter

    def self.safe_init_config(service)
      if !exists_config?(service)
        config = service.get_process_config
        Karma::ConfigWriter.export_config(service, config)
      end
      config = Karma::ConfigEngine::ConfigImporter.import_config(service)
      service.set_process_config(config)
    end

    def self.exists_config?(service)
      service_fn = "#{service.full_name}.config"
      config = JSON.parse(read_file(service_fn)).symbolize_keys rescue {}
      return config.present?
    end
    
    
    
  end
end