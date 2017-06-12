require 'karmap/engine'

module Karma::ConfigEngine

  module ConfigImporterExporter

    def self.safe_init_config(service_class)
      if !exists_config?(service_class)
        config = service_class.get_process_config
        export_config(service_class, config)
      end
      config = import_config(service_class)
      service_class.set_process_config(config)
    end

    def self.import_config(service_class)
      config = {}
      begin
        file_path = config_filepath(service_class)
        Karma.logger.debug { "Read config for service #{service_class} from file #{file_path}" }
        file_data = ::File.read(file_path)
        config = JSON.parse(file_data).symbolize_keys
        Karma.logger.debug { "Config: #{config}" }
      rescue StandardError => e
        Karma.logger.error { e }
      end
      config
    end

    # exports service config to file
    def self.export_config(service_class, config)
      location = service_class.config_location
      FileUtils.mkdir_p(location)
      file_path = config_filepath(service_class)
      Karma.logger.debug{ "writing config #{service_class} to file: #{file_path}" }
      Karma::FileHelper::write_file(file_path, config.to_json)
    end

    def self.exists_config?(service_class)
      config = {}
      file_path = config_filepath(service_class)
      file_data = ::File.read(file_path) rescue {}
      return file_data.present?
    end

    def self.config_filepath(service_class)
      filepath = ::File.join(service_class.config_location, "#{service_class.full_name}.config")
    end

  end
end
