require 'karmap/engine'

module Karma::ConfigEngine

  class ConfigImporter

    def self.import_config(service)
      service_fn = "#{service.full_name}.config"
      config = JSON.parse(read_file(service_fn)).symbolize_keys rescue {}
      Karma.logger.debug{ "read config from file: #{config}" }
      return config
    end

  end
end
