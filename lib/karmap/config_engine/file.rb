module Karma::ConfigEngine

  class File < Base

    def initialize(default_config:, options: {})
      @service_class = options[:service_class]
      @config = default_config || {}
      @runtime_config = @config
      @poll_intervall = options[:poll_intervall]
      @file_path = options[:file_path]
    end

    def start
      Karma.logger.debug { "#{$$} - started file watcher" }
      @thread = ::Thread.new do
        loop do
          read
          sleep @poll_intervall
        end
      end
    end

    def stop
      Karma.logger.debug { "#{$$} - stopped file watcher" }
      @thread.kill
    end
    
    private
    
    def read
      begin
        #read from file
        data = ::File.read(@file_path)
        @runtime_config = JSON.parse(data).symbolize_keys
        Karma.logger.info { "#{$$} - read config from file #{@runtime_config}" }
      rescue StandardError => e
        Karma.logger.error { e }
      end
    end

  end

end
