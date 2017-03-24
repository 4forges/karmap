require 'karmap'
require 'karmap/service_config'

module Karma

  class Service
    include Karma::ServiceConfig

    attr_accessor :notifier, :engine

    @@running_instance = nil

    def initialize
      @engine = Karma.engine_class.new
      @notifier = Karma.notifier_class.new
      @thread_pool = Karma::Thread::ThreadPool.new(Proc.new { perform }, { log_prefix: self.log_prefix })
      @thread_config_reader = Karma::Thread::SimpleTcpConfigReader.new(
        default_config: self.class.to_thread_config,
        port: env_port,
        logger: logger
      )
      @sleep_time = 1
      @running = false
    end

    def env_port
      ENV['PORT'] || 8899 # port comes from systemd unit file environment, 8899 is for testing
    end

    def log_prefix
      "#{self.name}@#{self.env_port}"
    end

    def name
      self.class.name.demodulize.downcase
    end

    def full_name
      "#{Karma.project_name}-#{name}"
    end

    def command
      "rails runner -e production \"#{self.class.name}.run\"" # override if needed
    end

    def perform
      # abstract, override this
      raise NotImplementedError
    end

    #################################################

    #################################################
    # abstract callbacks
    #################################################
    def before_start
      # abstract callback, override if needed
    end

    def after_start
      # abstract callback, override if needed
    end

    def before_stop
      # abstract callback, override if needed
    end

    def after_stop
      # abstract callback, override if needed
    end
    #################################################

    def self.run
      @@running_instance ||= self.new
      @@running_instance.run
    end

    def stop
      @running = false
    end

    def run
      Signal.trap('INT') do
        puts 'int trapped'
        stop
      end
      Signal.trap('TERM') do
        puts 'term trapped'
        stop
      end

      before_start
      @thread_config_reader.start
      @running = true
      after_start

      # notify queue after start
      message = engine.get_process_status_message(self, $$)
      notifier.notify(message)

      while @running do

        # notify queue each loop
        message = engine.get_process_status_message(self, $$)
        notifier.notify(message) if message.present? && message.valid?

        self.class.update_thread_config(@thread_config_reader.config) if @thread_config_reader.config.present?
        @thread_pool.manage(self.class.to_thread_config)

        sleep(@sleep_time)
      end

      before_stop
      stop_all_threads
      @thread_config_reader.stop
      after_stop

      # notify queue after stop
      message = engine.get_process_status_message(self, $$)
      notifier.notify(message)
    end

    def register
      message = Karma::Messages::ProcessRegisterMessage.new(
        host: ::Socket.gethostname,
        project: Karma.karma_project_id,
        service: self.name
      )
      notifier.notify(message)
    end

    def running_thread_count
      @thread_pool.running.size
    end

    def stop_all_threads
      @thread_pool.stop_all
    end

    private ##############################

    def logger
      @logger ||= Logger.new(
        "#{Karma.log_folder}/#{log_prefix}.log",
        Karma::LOGGER_SHIFT_AGE,
        Karma::LOGGER_SHIFT_SIZE,
        level: Logger::INFO,
        progname: log_prefix
      )
      return @logger
    end

  end
end
