require 'karmap/engine'

module Karma::ConfigEngine

  module ConfigImporter

    def self.import_config(service_class)
      begin
        Karma.logger.debug { "Read config for service #{service_class} from file #{self.config_filepath(service_class)}" }
        file_data = ::File.read(self.config_filepath(service_class))
        config = JSON.parse(file_data).symbolize_keys
        Karma.logger.debug { "Config: #{config}" }
      rescue StandardError => e
        Karma.logger.error { e }
      end
      config
    end
    
    def self.config_filepath(service_class)
      filepath = ::File.join(service_class.config_location, "#{service_class.full_name}.config")
    end

  end
end
