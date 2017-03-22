require 'karmap'
require 'karmap/service_config'

module Karma

  class Service
    include Karma::ServiceConfig

    LOGGER_SHIFT_AGE = 2
    LOGGER_SHIFT_SIZE = 52428800

    attr_accessor :notifier, :engine, :process_config, :thread_config

    @@running_instance = nil

    def initialize
      @engine = Karma.engine_class.new
      @notifier = Karma.notifier_class.new


      @running = false
      @thread_pool = Karma::Thread::ThreadPool.new(Proc.new { perform }, { log_prefix: self.log_prefix })
      @thread_config_reader = Karma::Thread::SimpleTcpConfigReader.new(@thread_config, env_port)
      @sleep_time = 1
    end

    def env_port
      ENV['PORT'] || 8899 # port comes from systemd unit file environment, 8899 is for testing
    end
    
    def log_prefix
      "log/#{self.name}-#{self.env_port}"
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
        sleep(@sleep_time)
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
