module Karma::ConfigEngine

  class File < Base

    def initialize(default_config:, options: {})
      @runtime_config = default_config
      @service_class = options[:service_class]
      @poll_intervall = options[:poll_intervall]
    end

    def start
      Karma.logger.debug { "started file watcher" }
      @thread = ::Thread.new do
        loop do
          @runtime_config = read
          sleep @poll_intervall
        end
      end
    end

    def stop
      Karma.logger.debug { "stopped file watcher" }
      @thread.kill
    end

    # do nothing because the configuration is already on the file
    def self.send_config(cls, options = {})
    end
    
    private
    
    def read
      Karma::ConfigEngine::ConfigImporterExporter.import_config(@service_class)
    end

  end

end
