# frozen_string_literal: true

require 'karmap'
require 'karmap/service_config'

module Karma
  # Watchdog class check running services
  class Watchdog
    include Karma::ServiceConfig

    port Karma.watchdog_port
    timeout_stop 30

    SHUTDOWN_SEC = 0
    CHECK_SERVICE_STATUS_EVERY_SEC = 10
    CHECK_CPU_EVERY_SEC = 60
    ONE_SECOND = 1

    attr_accessor :service_statuses, :cpu_timelines

    ### class attr accessors ###
    def self.config_location
      @@config_location ||= File.join(Karma.home_path, '.config', Karma.project_name)
    end

    def self.config_filename
      @@config_filename ||= "#{full_name}.config"
    end

    def self.engine_instance
      @@engine_instance ||= Karma.engine_instance
    end

    def self.logger
      @@logger ||= Karma.logger
    end
    ##############################

    def self.command
      if Rails.env.test?
        command_test
      else
        "bundle exec rails runner -e #{Karma.env} \"Karma::Watchdog.run\""
      end
    end

    def self.run
      (@@instance = self.new).run unless defined?(@@instance)
    end

    def self.export
      Watchdog.engine_instance.export_service(Watchdog)
      status = Watchdog.engine_instance.show_service(Watchdog)
      if status.empty?
        Watchdog.engine_instance.start_service(Watchdog)
      else
        Watchdog.engine_instance.restart_service(status.values[0].pid, service: Watchdog)
      end
    end

    # used by rake task :start_all
    def self.start_all_services
      # only call register on each service. Karma server will then push a ProcessConfigUpdateMessage that
      # will trigger the starting of instances.
      Karma.service_classes.each(&:register)
    end

    # used by rake task ::stop_all
    def self.stop_all_services
      status = Watchdog.engine_instance.show_all_services
      status.reject! { |_k, v| v.name == Watchdog.full_name }
      status.values.map(&:pid).each do |pid|
        Watchdog.engine_instance.stop_service(pid)
      end
    end

    # used by rake task ::stop_all
    def self.restart_all_services
      status = Watchdog.engine_instance.show_all_services
      status.reject! { |_k, v| v.name == Watchdog.full_name }
      status.values.map(&:pid).each do |pid|
        Watchdog.engine_instance.restart_service(pid)
      end
    end

    def initialize
      Watchdog.logger.info { "environment is #{Karma.env}" }
      @service_statuses = {}
      @cpu_timelines = {}
      @last_cpu_checked_at = Time.now
      @queue_client = Karma::Queue::Client.new
    end

    def run
      Watchdog.logger.info { 'enter' }
      # startup instructions
      register_services # register all services to karma
      deregister_services # de-register all service no more present into the config
      start_queue_poller
      init_traps

      # main loop:
      # check services status every CHECK_SERVICE_STATUS_EVERY_SEC (10) seconds
      # print 'alive message' every 60 seconds
      # exit from loop if a signal is trapped
      @running = true
      while @running
        limited_do(:check_services, CHECK_SERVICE_STATUS_EVERY_SEC) { check_services }
        limited_do(:log_alive, CHECK_SERVICE_STATUS_EVERY_SEC) { Watchdog.logger.info { 'alive' } }
        sleep ONE_SECOND
      end

      handle_traps
      shutdown_queue_poller
      shutdown_karma
    end

    private ##############################

    def self.command_test
      travis_build_dir = ENV['TRAVIS_BUILD_DIR'] || '.'
      File.open('./watchdog.run', 'w') do |file|
        file.write("cd #{travis_build_dir}\n")
        file.write("bundle exec rails runner -e #{Karma.env} \"Karma::Watchdog.run\"")
      end
      File.chmod(0o755, './watchdog.run')
      './watchdog.run'
    end

    def limited_do(key, interval, &block)
      @limited_procs_last_executions ||= {}
      if @limited_procs_last_executions[key].nil? || (Time.now - @limited_procs_last_executions[key] >= interval)
        block.call
        @limited_procs_last_executions[key] = Time.now
      end
    end

    # Starts the queue poller loop
    # The loop runs in a separated Thread
    def start_queue_poller
      @poller = ::Thread.new do
        loop do
          Watchdog.logger.info { "started polling queue #{Karma::Queue.incoming_queue_url}" }
          @queue_client.poll(queue_url: Karma::Queue.incoming_queue_url) do |msg|
            body = JSON.parse(msg.body).deep_symbolize_keys
            handle_message(body)
          end
          # if we are here, we are exited from the queue_client poll loop
          # in this case, we wait 10 seconds and restart the loop
          Watchdog.logger.error { 'error during polling... Wait 10 seconds and restart' }
          sleep 10
        end
      end
      Watchdog.logger.info { 'poller started' }
    end

    def shutdown_queue_poller
      @poller.kill
    end

    def init_traps
      Signal.trap('INT') do
        @trapped_signal = 'INT'
        @running = false
      end
      Signal.trap('TERM') do
        @trapped_signal = 'TERM'
        @running = false
      end
    end

    def handle_traps
      if @trapped_signal
        Watchdog.logger.info { "got signal #{@trapped_signal}" }
        sleep 0.5
      end
    end

    def shutdown_karma
      (0..Watchdog::SHUTDOWN_SEC - 1).each do |k|
        Watchdog.logger.info { "shutting down... #{Watchdog::SHUTDOWN_SEC - k}" }
        sleep 1
      end
    end

    # Checks running instances number and starts/stops instances if needed
    def check_running_count_for_service(service)
      # start instances
      if service.config_auto_start
        Watchdog.engine_instance.to_be_started_ports(service).each do |port|
          Watchdog.logger.info { "start new instance of #{service.name} on port #{port}" }
          Watchdog.engine_instance.start_service(service)
        end
      else
        Watchdog.logger.info { "autostart for service #{service.name} is disabled" }
      end

      # stop instances
      Watchdog.engine_instance.to_be_stopped_instances(service).each do |instance|
        Watchdog.logger.info { "stop instance #{instance.name}" }
        Watchdog.engine_instance.stop_service(instance.pid)
      end
    end

    # checks memory usage for all running services and instances.
    # Kills instances that are over limit
    def check_memory_usage_for_service(service)
      if service.config_memory_accounting?
        Watchdog.engine_instance.running_instances_for_service(service).each do |k, instance|
          pid = instance[:pid]
          process = Karma::System::Process.new(pid)
          memory_usage = process.memory.to_f * 1.kilobyte / 1.megabyte # in megabytes
          Watchdog.logger.info { "instance #{k}: used memory: #{memory_usage}MB, allowed: #{service.config_memory_max}MB" }
          if memory_usage > service.config_memory_max
            Watchdog.logger.info { "instance #{k} will be restarted because MEM is over quota" }
            Watchdog.engine_instance.restart_service(pid, service: service)
          else
            Watchdog.logger.info { "instance #{k} is OK" }
          end
        end
      else
        Watchdog.logger.info { "memory accounting disabled for service #{service}" }
      end
    end

    # checks cpu usage for all running services and instances.
    # Kills instances that are over limit for the last 5 times
    def check_cpu_usage_for_service(service)
      # kill by cpu usage
      @cpu_timelines[service.to_s] ||= {}
      service_cpu_timelines = {}
      Watchdog.engine_instance.running_instances_for_service(service).each do |k, instance|
        pid = instance[:pid]
        process = Karma::System::Process.new(pid)
        percent_cpu = process.percent_cpu
        service_cpu_timelines[pid] = @cpu_timelines[service.to_s][pid] || []
        service_cpu_timelines[pid].unshift(percent_cpu)
        service_cpu_timelines[pid] = service_cpu_timelines[pid][0..4]
        history = service_cpu_timelines[pid].map { |v| "#{service.is_cpu_over_quota?(v) ? '*' : ''}#{v.round(2)}%" }.join(", ")
        Watchdog.logger.info { "cpu history: [#{history}]" }
        if service.config_cpu_accounting?
          cpu_test = service_cpu_timelines[pid].map { |v| service.is_cpu_over_quota?(v) }.all?
          if cpu_test
            Watchdog.logger.info { "instance #{k} will be restarted because CPU is over quota" }
            Watchdog.engine_instance.restart_service(pid, { service: service })
          else
            Watchdog.logger.info { "instance #{k} is OK" }
          end
        else
          Watchdog.logger.info { "CPU accounting disabled for service #{service}" }
        end
      end
      @cpu_timelines[service.to_s] = service_cpu_timelines
    end

    # Notifies the Karma server about the current host and all Karma::Service subclasses
    def register_services
      Watchdog.logger.info { "registering services... #{Karma.service_classes.count} services found" }
      Karma.service_classes.each do |cls|
        Watchdog.logger.info { "registering #{cls.name}..." }
        Watchdog.engine_instance.export_service(cls)
        cls.register
      end
      Watchdog.logger.info { "done registering services" }
    end

    # Checks enabled services, and deregister services that are not present anymore into the gemma config
    def deregister_services
      Watchdog.logger.info { "deregistering services..." }
      enabled_services_names = Watchdog.engine_instance.show_enabled_services&.reject! { |name| name == Watchdog.full_name }
      if enabled_services_names.present?
        to_be_cleaned_classes = enabled_services_names.map { |name| Karma::Helpers.service_class_from_name(name) } - Karma.service_classes
        to_be_cleaned_classes.each do |service_class|
          Watchdog.logger.info { "removing #{service_class}..." }
          Watchdog.engine_instance.show_service(service_class).values.map do |s|
            Watchdog.logger.info { "stopping pid #{s['pid']}..." }
            Watchdog.engine_instance.stop_service(s['pid'])
          end
          sleep(1) until Watchdog.engine_instance.show_service(service_class).empty?
          Watchdog.engine_instance.remove_service(service_class)
        end
      else
        Watchdog.logger.info { "no services to remove" }
      end
    end

    def handle_message(message)
      Watchdog.logger.info { "#{__method__} INCOMING MESSAGE: #{message}" }
      case message[:type]
      when Karma::Messages::ProcessCommandMessage.name
        # set the array of discovered services for validation
        Karma::Messages::ProcessCommandMessage.services = Karma.service_classes.map(&:to_s)
        msg = Karma::Messages::ProcessCommandMessage.new(message)
        Karma.error(msg.errors) unless msg.valid?
        handle_process_command(msg)
      when Karma::Messages::ProcessConfigUpdateMessage.name
        msg = Karma::Messages::ProcessConfigUpdateMessage.new(message)
        Karma.error(msg.errors) unless msg.valid?
        handle_process_config_update(msg)
      else
        Karma.error("Invalid message type: #{message[:type]}")
      end
    rescue ::Exception => e
      Watchdog.logger.error { "error processing message - #{e.message}" }
    end

    def handle_process_command(msg)
      case msg.command
      when Karma::Messages::ProcessCommandMessage::COMMANDS[:start]
        cls = Karma::Helpers.constantize(msg.service)
        Watchdog.engine_instance.start_service(cls)
      when Karma::Messages::ProcessCommandMessage::COMMANDS[:stop]
        Watchdog.engine_instance.stop_service(msg.pid)
      when Karma::Messages::ProcessCommandMessage::COMMANDS[:restart]
        Watchdog.engine_instance.restart_service(msg.pid)
      else
        Watchdog.logger.warn { "invalid process command: #{msg.command} - #{msg.inspect}" }
      end
    end

    def handle_process_config_update(msg)
      cls = Karma::Helpers.constantize(msg.service)
      old_config = cls.read_config
      new_config = msg.to_config

      if new_config == old_config
        # no changes in configuration
        Watchdog.logger.info { 'config not changed' }
      else
        # export new configuration
        Karma::ConfigEngine::ConfigImporterExporter.export_config(cls, new_config)
        Watchdog.engine_instance.export_service(cls)
        check_running_count_for_service(cls)
        Karma.config_engine_class.send_config(cls)
      end
    end

    def check_services
      check_cpu = Time.now - @last_cpu_checked_at > CHECK_CPU_EVERY_SEC
      Karma.service_classes.each do |service_class|
        Karma::ConfigEngine::ConfigImporterExporter.safe_init_config(service_class)
        check_running_count_for_service(service_class)
        check_memory_usage_for_service(service_class)
        check_cpu_usage_for_service(service_class) if check_cpu
      end
      @last_cpu_checked_at = Time.now if check_cpu # updates last_cpu_checked_at
      sync_services_statuses
    end

    def sync_services_statuses
      Watchdog.logger.debug { 'sync_services_statuses' }
      new_service_statuses = Watchdog.engine_instance.show_all_services.reject! { |_k, v| v.name == Watchdog.full_name } || []
      new_running_instances = new_service_statuses.select { |_i, s| s.status == Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running] }
      Watchdog.logger.debug { "currently #{new_running_instances.size} running instances" }
      Watchdog.logger.debug { "#{new_running_instances.group_by { |_i, s| s.name }.map { |i, g| "#{i}: #{g.size}" }.join(', ')}" }

      service_statuses.each do |instance, status|
        if new_service_statuses[instance].present?
          cls = Karma::Helpers.service_class_from_name(status.name)
          if new_service_statuses[instance].pid != status.pid
            # same service instance but different pid: notify server
            Watchdog.logger.info { "found restarted instance (#{instance}, old pid: #{status.pid}, new pid: #{new_service_statuses[instance].pid})" }
            cls.notify_status(pid: status.pid, params: { status: Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead] })
          elsif new_service_statuses[instance].status != status.status
            # service instance with changed status: notify server
            Watchdog.logger.info { "found instance with changed state (#{instance}, was: #{status.status}, now: #{new_service_statuses[instance].status})" }
            cls.notify_status(pid: status.pid)
          end
        else
          # service instance disappeared for some reason: notify server
          Watchdog.logger.info { "found missing instance (#{instance})" }
          cls.notify_status(pid: status.pid, params: { status: Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead] })
        end
      end
      @service_statuses = new_service_statuses
    end
  end
end
