require 'karmap'
require 'karmap/service_config'

module Karma

  class Service
    include Karma::ServiceConfig
    include Karma::Helpers

    attr_reader :config_reader

    def self.engine
      Karma.engine_instance
    end

    def self.init_config_reader_for_instance(instance)
      case Karma.config_engine
      when 'tcp'
        Karma::ConfigEngine::SimpleTcp.new(default_config: self.get_process_config, options: { port: instance.instance_port })
      when 'file'
        Karma::ConfigEngine::File.new(default_config: self.get_process_config, options: { service_class: self, poll_intervall: 2.seconds })
      end
    end

    def initialize
      @running = false
      @run_sleep_seconds = 1

      # init thread pool
      @thread_pool = Karma::Thread::ThreadPool.new( running: Proc.new { perform }, performance: Proc.new{ ::Thread.current[:performance] = performance }, custom_inspect: Proc.new { custom_inspect } )
      # init config reader
      @config_reader = self.class.init_config_reader_for_instance(self)

      Karma::ConfigEngine::ConfigImporterExporter.safe_init_config(self.class)
    end

    def self.is_cpu_over_quota?(val)
      config_cpu_accounting? && val > config_cpu_quota
    end

    def performance
      # override this with custom performance calculation.
      # return a value between 0-100, where 100 is good and 0 is bad.
      0
    end

    def custom_inspect
      # override this with custom inspect_info
      'custom_inspect'
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

    def self.command
      # override this with custom run command
      "bin/rails runner -e #{Karma.env} \"#{name}.run\""
    end

    def self.run
      (@@instance = self.new).run if !defined?(@@instance)
    end

    def self.version
      ret = nil
      if Karma.version_file_path.present?
        if File.exists?(Karma.version_file_path)
          begin
            f = File.open(Karma.version_file_path)
            ret = f.gets
          rescue ::Exception => e
            ret = 'error reading file'
          ensure
            f.close unless f.nil?
          end
        else
          ret = 'file does not exists'
        end
      else
        ret = 'no version set'
      end
      ret
    end

    def self.config_location
      File.join(Karma.home_path, '.config', Karma.project_name)
    end

    def self.config_filename
      "#{full_name}.config"
    end

    def self.register
      begin
        # this version is the last version of the repo
        message = Karma::Messages::ProcessRegisterMessage.new(
          host: ::Socket.gethostname,
          project: Karma.karma_project_id,
          service: demodulized_name,
          memory_max: config_memory_max,
          cpu_quota: config_cpu_quota,
          min_running: config_min_running,
          max_running: config_max_running,
          auto_restart: config_auto_restart,
          auto_start: config_auto_start,
          push_notifications: config_push_notifications,
          log_level: Karma.logger.level,
          num_threads: config_num_threads,
          version: version
        )
        Karma.notifier_instance.notify(message)
      rescue ::Exception => e
        Karma.logger.error { e }
      end
    end

    def stop
      @running = false
      before_stop
    end

    def run
      Karma.logger.info{ "#{__method__}: enter" }
      Karma.engine_instance.after_start_service(self)

      Signal.trap('INT') do
        stop
      end
      Signal.trap('TERM') do
        stop
      end

      before_start
      @config_reader.start
      @running = true
      after_start

      # notify queue after start
      notify_status

      last_notified_at = nil
      while @running do

        # notify queue each 'self.class.notify_interval' sec (default 5 sec)
        if last_notified_at.nil? || (Time.now - last_notified_at) > self.class.config_notify_interval
          notify_status
          last_notified_at = Time.now
        end

        # manage thread config update
        self.class.set_process_config(@config_reader.runtime_config) if @config_reader.runtime_config.present?
        @thread_pool.manage(self.class.get_process_config)

        Karma.logger.debug { "#{__method__}: alive" }
        sleep(@run_sleep_seconds)
      end

      stop_all_threads
      @config_reader.stop

      # note: after_stop callback will not be called if service has been killed (not stopped correctly)
      after_stop

      # notify queue after stop
      notify_status(params: { status: Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:stopped] })
      Karma.engine_instance.after_stop_service(self)
    end

    def self.read_config
      Karma::ConfigEngine::ConfigImporterExporter.import_config(self)
    end

    def self.running_instances_count
      Karma.engine_instance.running_instances_for_service(self).size
    end

    def running_thread_count
      @thread_pool.running.size
    end

    def stop_all_threads
      @thread_pool.stop_all
    end

    def notify_status(pid: $$, params: {})
      params[:active_threads] = @thread_pool.active.size
      params[:execution_time] = @thread_pool.average_execution_time
      params[:performance_execution_time] = @thread_pool.average_performance_execution_time
      params[:performance] = @thread_pool.average_performance
      # this version is the current version of the running instance
      params[:current_version] = self.class.version
      self.class.notify_status(pid: pid, params: params)
    end

    def self.notify_status(pid:, params: {})
      message = Karma.engine_instance.get_process_status_message(self, pid, params)
      Karma.notifier_instance.notify(message) if message.present? && message.valid?
    end
  end
end
