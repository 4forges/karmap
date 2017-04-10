module Karma::Thread
  class FakeConfigReader
    cattr_writer :num_threads
    attr_reader :config

    def initialize(default_config)
      @config = default_config
      @@num_threads = @config[:num_threads]
    end

    def start
      @check_config_task = Concurrent::TimerTask.new(execution_interval: 5, timeout_interval: 5) do
        refresh_config
        Karma.logger.debug { "new config: #{@config.inspect}" }
      end
      @check_config_task.execute
    end

    private

    def refresh_config
      @config = { num_threads: @@num_threads }
    end

  end
end
