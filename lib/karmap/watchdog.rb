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

    # Utility method for getting a service class from an instance name
    # ie. project-name-dummy-service -> DummyService
    def self.service_class_from_name(name)
      service_name = Karma::Helpers.classify(name.sub("#{Karma.project_name}-", ''))
      return Karma::Helpers.constantize(service_name)
    end

    def self.command
      "bundle exec rails runner -e #{Karma.env} \"Karma::Watchdog.run\""
    end

    def self.run
      (@@instance = self.new).run if !defined?(@@instance)
    end

    def self.export
      Watchdog.engine_instance.export_service(Watchdog)
      status = Watchdog.engine_instance.show_service(Watchdog)
      if status.empty?
        Watchdog.engine_instance.start_service(Watchdog)
      else
        Watchdog.engine_instance.restart_service(status.values[0].pid, { service: Watchdog })
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
      Watchdog.logger.info { "#{__method__}: environment is #{Karma.env}" }
      @service_statuses = {}
      @cpu_timelines = {}
      @queue_client = Karma::Queue::Client.new
    end

    def run
      Watchdog.logger.info { "#{__method__}: enter" }
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
      i = 1 # start from 1 to check services after 10 seconds, the first time we enter the loop
      while @running
        check_services_status if (i % CHECK_SERVICE_STATUS_EVERY_SEC).zero?
        Watchdog.logger.info { "#{__method__}: alive" } if i.zero?
        i = (i + 1) % 60
        sleep ONE_SECOND
      end

      handle_traps
      shutdown_queue_poller
      shutdown_karma
    end

    private ##############################

    def start_queue_poller
      @poller = ::Thread.new do
        loop do
          Watchdog.logger.info { "#{__method__}: started polling queue #{Karma::Queue.incoming_queue_url}" }
          @queue_client.poll(queue_url: Karma::Queue.incoming_queue_url) do |msg|
            body = JSON.parse(msg.body).deep_symbolize_keys
            handle_message(body)
          end
          # if we are here, we are exited from the queue_client poll loop
          # in this case, we wait 10 seconds and restart the loop
          Watchdog.logger.error { "#{__method__}: error during polling... Wait 10 seconds and restart" }
          sleep 10
        end
      end
      Watchdog.logger.info { "#{__method__}: poller started" }
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
        Watchdog.logger.info { "#{__method__}: got signal #{@trapped_signal}" }
        sleep 0.5
      end
    end

    def shutdown_karma
      (0..Watchdog::SHUTDOWN_SEC - 1).each do |k|
        Watchdog.logger.info { "#{__method__}: shutting down... #{Watchdog::SHUTDOWN_SEC - k}" }
        sleep 1
      end
    end

    def ensure_service_instances_count(service)
      Karma::ConfigEngine::ConfigImporterExporter.safe_init_config(service)

      # start instances
      if service.config_auto_start
        Watchdog.engine_instance.to_be_started_ports(service).each do |port|
          Watchdog.logger.debug { "#{__method__}: start new instance of #{service.name} on port #{port}" }
          Watchdog.engine_instance.start_service(service)
        end
      else
        Watchdog.logger.debug { "#{__method__}: autostart for service #{service.name} is false" }
      end

      # stop instances
      Watchdog.engine_instance.to_be_stopped_instances(service).each do |instance|
        Watchdog.logger.debug { "#{__method__}: stop instance #{instance.name}" }
        Watchdog.engine_instance.stop_service(instance.pid)
      end

      # kill by memory usage
      Watchdog.engine_instance.running_instances_for_service(service).each do |k, instance|
        pid = instance[:pid]
        process = Karma::System::Process.new(pid)
        memory_usage = process.memory / 1.kilobyte # in megabytes
        Watchdog.logger.info { "instance #{k}: used memory: #{memory_usage}MB, allowed: #{service.config_memory_max}MB" }
        if service.config_memory_max.present? && memory_usage > service.config_memory_max
          process.gracefully_stop
          Watchdog.logger.info { "instance #{k} STOPPED" }
        else
          Watchdog.logger.info { 'OK' }
        end
      end

      # kill by cpu usage
      @cpu_timelines[service.to_s] ||= {}
      service_cpu_timelines = {}
      Watchdog.engine_instance.running_instances_for_service(service).each do |k, instance|
        pid = instance[:pid]
        process = Karma::System::Process.new(pid)
        percent_cpu = process.percent_cpu
        service_cpu_timelines[pid] = @cpu_timelines[service.to_s][pid] || []
        service_cpu_timelines[pid].unshift(percent_cpu)
        service_cpu_timelines[pid] = service_cpu_timelines[pid][0..9]
        cpu_test = service.config_cpu_quota > 0 && service_cpu_timelines[pid].select { |v| v > service.config_cpu_quota }.size > 5
        history = "[" + service_cpu_timelines[pid].map { |x| "#{service.config_cpu_quota > 0 && x > service.config_cpu_quota ? '*' : ''}#{x.round(2)}%" }.join(", ") + "]"
        Watchdog.logger.info { "cpu out of bounds #{history}" }
        if cpu_test
          process.gracefully_stop
          Watchdog.logger.info { "instance #{k} STOPPED" }
        else
          Watchdog.logger.info { 'OK' }
        end
      end
      @cpu_timelines[service.to_s] = service_cpu_timelines
    end

    # Notifies the Karma server about the current host and all Karma::Service subclasses
    def register_services
      Watchdog.logger.info { "#{__method__}: registering services... #{Karma.service_classes.count} services found" }
      Karma.service_classes.each do |cls|
        Watchdog.logger.info { "#{__method__}: registering #{cls.name}..." }
        Watchdog.engine_instance.export_service(cls)
        cls.register
      end
      Watchdog.logger.info { "#{__method__}: done registering services" }
    end

    # Checks enabled services, and deregister services that are not present anymore into the gemma config
    def deregister_services
      Watchdog.logger.info { "#{__method__}: deregistering services..." }
      enabled_services_names = Watchdog.engine_instance.show_enabled_services.reject! { |name| name == Watchdog.full_name }
      if enabled_services_names.present?
        to_be_cleaned_classes = enabled_services_names.map { |name| Watchdog.service_class_from_name(name) } - Karma.service_classes
        to_be_cleaned_classes.each do |service_class|
          Watchdog.logger.info { "#{__method__}: removing #{service_class}..." }
          Watchdog.engine_instance.show_service(service_class).values.map do |s|
            Watchdog.logger.info { "#{__method__}: stopping pid #{s['pid']}..." }
            Watchdog.engine_instance.stop_service(s['pid'])
          end
          sleep(1) until Watchdog.engine_instance.show_service(service_class).empty?
          Watchdog.engine_instance.remove_service(service_class)
        end
      else
        Watchdog.logger.info { "#{__method__}: no services to remove" }
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
      Watchdog.logger.error { "#{__method__}: error processing message - #{e.message}" }
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
        Watchdog.logger.warn { "#{__method__}: invalid process command: #{msg.command} - #{msg.inspect}" }
      end
    end

    def handle_process_config_update(msg)
      cls = Karma::Helpers.constantize(msg.service)
      new_config = msg.to_config
      old_config = cls.read_config

      if new_config == old_config
        # no changes in configuration
        Watchdog.logger.info { "#{__method__}: config not changed" }

      else
        # export new configuration
        Karma::ConfigEngine::ConfigImporterExporter.export_config(cls, new_config)
        Watchdog.engine_instance.export_service(cls)
        ensure_service_instances_count(cls)
        Karma.config_engine_class.send_config(cls)
      end
    end

    def check_services_status
      Karma.service_classes.each do |service_class|
        ensure_service_instances_count(service_class)
      end
      sleep 1

      new_service_statuses = Watchdog.engine_instance.show_all_services.reject! { |_k, v| v.name == Watchdog.full_name }

      new_running_instances = new_service_statuses.select { |_i, s| s.status == Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running] }
      Watchdog.logger.debug { "#{__method__}: currently #{new_running_instances.size} running instances" }
      Watchdog.logger.debug { "#{__method__}: #{new_running_instances.group_by { |_i, s| s.name }.map { |i, g| "#{i}: #{g.size}" }.join(', ')}" }

      service_statuses.each do |instance, status|
        if new_service_statuses[instance].present?
          if new_service_statuses[instance].pid != status.pid
            # same service instance but different pid: notify server
            Watchdog.logger.info { "#{__method__}: found restarted instance (#{instance}, old pid: #{status.pid}, new pid: #{new_service_statuses[instance].pid})" }
            cls = Watchdog.service_class_from_name(status.name)
            cls.notify_status(pid: status.pid, params: { status: Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead] })
          elsif new_service_statuses[instance].status != status.status
            # service instance with changed status: notify server
            Watchdog.logger.info { "#{__method__}: found instance with changed state (#{instance}, was: #{status.status}, now: #{new_service_statuses[instance].status})" }
            cls = Watchdog.service_class_from_name(status.name)
            cls.notify_status(pid: status.pid)
          end
        else
          # service instance disappeared for some reason: notify server
          Watchdog.logger.info { "#{__method__}: found missing instance (#{instance})" }
          cls = Watchdog.service_class_from_name(status.name)
          cls.notify_status(pid: status.pid, params: { status: Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead] })
        end
      end
      @service_statuses = new_service_statuses
    end
  end
end
