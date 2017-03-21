require 'karmap'
require 'karmap/service_config'

module Karma

  class Service
    include Karma::ServiceConfig
    #################################################
    # process configuration
    #################################################
    base_min_running  1
    base_max_running  1
    base_port         5000
    base_auto_restart true

    #################################################
    # thread configuration
    #################################################
    base_num_threads  1
    base_log_level    :info
    
    LOGGER_SHIFT_AGE = 2
    LOGGER_SHIFT_SIZE = 52428800

    attr_accessor :notifier, :engine, :process_config, :thread_config, :sleep_time

    @@running_instance = nil

    def initialize
      @engine = Karma.engine_class.new
      @notifier = Karma.notifier_class.new
      @thread_config = {
        num_threads: self.class.num_threads,
        log_level: self.class.log_level
      }

      @process_config = {
        min_running: self.class.min_running,
        max_running: self.class.max_running,
        memory_max: self.class.memory_max,
        cpu_quota: self.class.cpu_quota,
        auto_start: self.class.auto_start,
        auto_restart: self.class.auto_restart
      }

      @running = false
      @thread_pool = Karma::Thread::ThreadPool.new(Proc.new { perform }, { log_prefix: self.log_prefix })
      @thread_config_reader = Karma::Thread::SimpleTcpConfigReader.new(@thread_config)
      @sleep_time = 1
    end

    def log_prefix
      "log/#{self.name}-#{self.process_config[:port]}"
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

    def log_location
      nil # override this
    end

    def perform
      # abstract, override this
      raise NotImplementedError
    end

    def update_process_config(config)
      process_config.merge!(config)
    end

    def update_thread_config(config)
      thread_config.merge!(config)
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
      if @@running_instance.nil?
        @@running_instance = self.new()
        @@running_instance.run
      end
    end

    def run
      Signal.trap('INT') do
        puts 'int trapped'
        thread_config[:running] = false
      end
      Signal.trap('TERM') do
        puts 'term trapped'
        thread_config[:running] = false
      end

      before_start
      @thread_config_reader.start
      thread_config[:running] = true
      after_start

      # notify queue after start
      message = engine.get_process_status_message($$)
      notifier.notify(message)

      while thread_config[:running] do

        # notify queue each loop
        message = engine.get_process_status_message($$)
        notifier.notify(message)

        thread_config.merge!(@thread_config_reader.config)
        @thread_pool.manage(thread_config)
        sleep(sleep_time)
      end

      before_stop
      @thread_pool.stop_all
      after_stop

      # notify queue after stop
      message = engine.get_process_status_message($$)
      notifier.notify(message)
    end

    def register
      message = Karma::Messages::ProcessRegisterMessage.new(
        host: ::Socket.gethostname,
        project: Karma.karma_project_id,
        service: full_name
      )
      notifier.notify(message)
    end


  end
end
