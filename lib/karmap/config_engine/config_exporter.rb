require 'karmap/engine'

module Karma::ConfigEngine

  module ConfigExporter

    def self.safe_init_config(service)
      if !exists_config?(service)
        config = service.get_process_config
        Karma::ConfigEngine::ConfigExporter.export_config(service, config)
      end
      config = Karma::ConfigEngine::ConfigImporter.import_config(service)
      service.set_process_config(config)
    end

    def self.exists_config?(service_class)
      file_path = config_filepath(service_class)
      config = JSON.parse(read_file(file_path)).symbolize_keys rescue {}
      return config.present?
    end

    # exports service config to file
    def self.export_config(service_class, config)
      location = service_class.config_location
      FileUtils.mkdir_p(location)
      file_path = config_filepath(service_class)
      Karma.logger.debug{ "writing config #{service_class} to file: #{file_path}" }
      Karma::FileHelper::write_file(file_path, config.to_json)
    end

    def self.config_filepath(service_class)
      filepath = ::File.join(service_class.config_location, "#{service_class.full_name}.config")
    end

  end
end