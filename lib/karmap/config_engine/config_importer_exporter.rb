require 'karmap/engine'

module Karma::ConfigEngine

  module ConfigImporterExporter

    # sets class config reading it from the file ( exports it before reading if the config file doesn't exist )
    def self.safe_init_config(service_class)
      if !exists_config?(service_class)
        config = service_class.get_process_config # compiles config hash from Class configuration
        export_config(service_class, config) # exports config to file
      end
      config = import_config(service_class) # read config from file
      service_class.set_process_config(config) # passes config to service class
    end
    
    # reads the config from the file and returns it as hash
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
      file_path = config_filepath(service_class)
      file_data = ::File.read(file_path) rescue {}
      return file_data.present?
    end

    def self.config_filepath(service_class)
      ::File.join(service_class.config_location, service_class.config_filename)
    end

  end
end
