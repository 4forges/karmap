require 'karmap'
require 'karmap/service_config'

module Karma

  class Service
    include Karma::ServiceConfig

    attr_accessor :notifier, :engine

    @@running_instance = nil

    def initialize
      @engine = Karma.engine_class.new
      Karma.logger.info 'Engine initialized'
      @notifier = Karma.notifier_class.new
      @thread_pool = Karma::Thread::ThreadPool.new(Proc.new { perform })
      @thread_config_reader = Karma::Thread::SimpleTcpConfigReader.new(
        default_config: self.class.to_thread_config,
        port: env_port
      )
      @sleep_time = 1
      @running = false
    end

    def env_port
      ENV['PORT'] || 8899 # port comes from service environment, 8899 is for testing
    end

    def env_identifier
      ENV['KARMA_IDENTIFIER']
    end

    def log_prefix
      env_identifier
    end

    def name
      self.class.name.demodulize
    end

    def full_name
      "#{Karma.project_name}-#{name}".downcase
    end

    def identifier(port = nil)
      "#{full_name}@#{port||env_port}"
    end

    def command
      "rails runner -e #{Karma.env} \"#{self.class.name}.run\"" # override if needed
    end

    def timeout_stop
      5 # override if needed
    end

    def perform
      # abstract, override this
      raise NotImplementedError
    end

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
        @@running_instance = true
        self.new.run
      end
    end

    def stop
      @running = false
      before_stop
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
      
      last_notified_at = nil
      while @running do

        # notify queue each 5 sec
        if last_notified_at.nil? || (Time.now - last_notified_at) > 5
          message = engine.get_process_status_message(self, $$)
          notifier.notify(message) if message.present? && message.valid?
          last_notified_at = Time.now
        end

        self.class.update_thread_config(@thread_config_reader.config) if @thread_config_reader.config.present?
        @thread_pool.manage(self.class.to_thread_config)

        Karma.logger.debug 'Service is running'
        sleep(@sleep_time)
      end

      stop_all_threads
      @thread_config_reader.stop

      # note: after_stop callback will not be called if service has been killed (not stopped correctly)
      after_stop

      # notify queue after stop
      message = engine.get_process_status_message(self, $$)
      notifier.notify(message)
    end

    def register
      begin
        message = Karma::Messages::ProcessRegisterMessage.new(
          host: ::Socket.gethostname,
          project: Karma.karma_project_id,
          service: self.name
        )
        notifier.notify(message)
      rescue ::Exception => e
        # TODO HANDLE THIS
        Karma.logger.error e
      end
    end

    def running_thread_count
      @thread_pool.running.size
    end

    def stop_all_threads
      @thread_pool.stop_all
    end

  end
end
