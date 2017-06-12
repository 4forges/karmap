require 'karmap'

module Karma::ConfigWriter

  # exports service config to file
  def self.export_config(service, config)
    location = service.config_location
    FileUtils.mkdir_p(location)
    service_fn = "#{service.full_name}.config"
    file_path = File.join(location, service_fn)
    Karma.logger.debug{ "writing config #{config} to file: #{file_path}" }
    Karma::FileHelper::write_file(file_path, config.to_json)
  end

end
