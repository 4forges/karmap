module Karma::ConfigReaders

  class File

    attr_reader :runtime_config

    def initialize(service_class:, poll_intervall: )
      @service_class = service_class
      @config = default_config || {}
      @runtime_config = @config
      @poll_intervall = poll_intervall
    end

    def start
      Karma.logger.debug { "#{$$} - started file watcher" }
      @thread = ::Thread.new do
        loop do
          begin
            #read from file
            @runtime_config = JSON.parse(data).symbolize_keys
            Karma.logger.info { "#{$$} - read config from file #{@runtime_config}" }
          rescue StandardError => e
            Karma.logger.error { e }
          end
          sleep @poll_intervall
        end
      end
    end

    def stop
      Karma.logger.debug { "#{$$} - stopped file watcher" }
      @thread.kill
    end

  end

end
