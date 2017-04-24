require 'karmap'
require 'karmap/service_config'

module Karma

  class Service
    include Karma::ServiceConfig
    include Karma::Helpers

    @@instance = nil

    def initialize
      @thread_pool = Karma::Thread::ThreadPool.new( running: Proc.new { perform }, performance: Proc.new{ ::Thread.current[:performance] = performance } )
      default_config = Karma.engine_instance.import_config(self)
      if default_config.present?
        Karma.logger.info{ 'read config from file' }
        self.class.set_process_config(default_config)
        self.class.set_thread_config(default_config)
      end
      @thread_config_reader = Karma::Thread::SimpleTcpConfigReader.new(
        default_config: self.class.get_thread_config,
        port: instance_port
      )
      @sleep_time = 1
      @running = false
    end

    def command
      "bin/rails runner -e #{Karma.env} \"#{self.class.name}.run\"" # override if needed
    end

    def timeout_stop
      5 # override if needed
    end

    def performance
      0
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
      if @@instance.nil?
        @@instance = self.new
        @@instance.run
      end
    end

    def self.register
      begin
        message = Karma::Messages::ProcessRegisterMessage.new(
          host: ::Socket.gethostname,
          project: Karma.karma_project_id,
          service: self.demodulized_name,
          memory_max: self.config_memory_max,
          cpu_quota: self.config_cpu_quota,
          min_running: self.config_min_running,
          max_running: self.config_max_running,
          auto_restart: self.config_auto_restart,
          auto_start: self.config_auto_start,
          log_level: Karma.logger.level,
          num_threads: self.config_num_threads
        )
        Karma.notifier_instance.notify(message)
      rescue ::Exception => e
        # TODO HANDLE THIS
        Karma.logger.error{ e }
      end
    end

    def stop
      @running = false
      before_stop
    end

    def run
      Karma.logger.info{ "#{__method__}: enter" }

      Signal.trap('INT') do
        stop
      end
      Signal.trap('TERM') do
        stop
      end

      before_start
      @thread_config_reader.start
      @running = true
      after_start

      # notify queue after start
      notify_status

      last_notified_at = nil
      while @running do

        # notify queue each 5 sec
        if last_notified_at.nil? || (Time.now - last_notified_at) > 5
          notify_status
          last_notified_at = Time.now
        end

        # manage thread config update
        self.class.set_thread_config(@thread_config_reader.runtime_config) if @thread_config_reader.runtime_config.present?
        @thread_pool.manage(self.class.get_thread_config)

        Karma.logger.debug{ "#{__method__}: alive" }
        sleep(@sleep_time)
      end

      stop_all_threads
      @thread_config_reader.stop

      # note: after_stop callback will not be called if service has been killed (not stopped correctly)
      after_stop

      # notify queue after stop
      notify_status(status: Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:stopped])
    end

    def running_thread_count
      @thread_pool.running.size
    end

    def stop_all_threads
      @thread_pool.stop_all
    end

    def notify_status(pid: $$, status: nil)
      active_threads = @thread_pool.active.size
      params = {
        active_threads: active_threads,
        execution_time: @thread_pool.average_execution_time,
        performance_execution_time: @thread_pool.average_performance_execution_time,
        performance: @thread_pool.average_performance
      }
      params[:status] = status if status.present?
      message = Karma.engine_instance.get_process_status_message(self, pid, params)
      if message.present? && message.valid?
        Karma.notifier_instance.notify(message)
      end
    end

  end
end
