require 'karmap'
require 'karmap/helpers'
require 'karmap/service_config'

module Karma

  class Watchdog
    include Karma::ServiceConfig

    port Karma.watchdog_port

    SHUTDOWN_SEC = 0
    START_COMMAND = 'start'
    STOP_COMMAND = 'stop'

    @@service_classes = nil
    @@running_instance = nil
    @@queue_client = nil

    attr_accessor :engine

    def self.run
      @@running_instance ||= self.new
      @@running_instance.run
    end

    def initialize
      Karma.logger.info { "Watchdog initialized with env: #{Karma.env}" }
      Karma.logger.debug
      @engine = Karma.engine_class.new
      Karma.logger.info 'Engine initialized'
    end

    def run
      Karma.logger.info('Watchdog entered run method')
      register
      @poller = ::Thread.new do
        while true
          perform
          Karma.logger.error 'Error during polling'
          sleep 10
        end
      end
      Karma.logger.info 'Poller started'
      Signal.trap('INT') do
        @trapped_signal = 'INT'
        @running = false
      end
      Signal.trap('TERM') do
        @trapped_signal = 'TERM'
        @running = false
      end
      @running = true
      i = 0
      while @running do
        sleep 1
        i += 1
        if i%5.zero?
          check_processes
        end
        if i%60.zero?
          Karma.logger.info 'watchdog is running'
          i = 0
        end
      end
      if @trapped_signal
        Karma.logger.info "Got signal #{@trapped_signal}"
        sleep 0.5
      end
      @poller.kill
      (0..Karma::Watchdog::SHUTDOWN_SEC-1).each do |i|
        Karma.logger.info("Gracefully shutdown... #{Karma::Watchdog::SHUTDOWN_SEC-i}")
        sleep 1
      end
    end

    def env_port
      ENV['PORT']
    end

    def env_identifier
      ENV['KARMA_IDENTIFIER']
    end

    #################################################
    # watchdog config (for export)
    #################################################
    def log_prefix
      env_identifier
    end

    def name
      self.class.name.demodulize
    end

    def full_name
      "#{Karma.project_name}-#{name}".downcase
    end

    def identifier
      "#{full_name}@#{env_port}"
    end

    def command
      "bundle exec rails runner -e #{Karma.env} \"Karma::Watchdog.run\""
    end

    def timeout_stop
      30
    end

    def self.export
      s = self.new
      s.engine.export_service(s)
      status = s.engine.show_service(s)
      if status.empty?
        s.engine.start_service(s)
      else
        s.engine.restart_service(status.values[0].pid, { service: s })
      end
    end
    #################################################

    def service_classes
      @@service_classes ||= Karma.services.select{|c| constantize(c).new.is_a?(Karma::Service) rescue false}.map{|c| constantize(c)}
      return @@service_classes
    end

    def self.start_all_services
      s = self.new
      Karma.logger.info('Starting all services...')
      s.service_classes.each do |cls|
        Karma.logger.info("Starting #{cls.name}...")
        service = cls.new
        s.engine.start_service(service)
        service.register
      end
      Karma.logger.info('Done starting services')
    end

    def self.stop_all_services
      s = self.new
      Karma.logger.info('Stopping all services...')
      status = s.engine.show_all_services
      status.values.map(&:pid).each do |pid|
        Karma.logger.info("Stopping pid #{pid}...")
        s.engine.stop_service(pid)
      end
      Karma.logger.info('Done stopping services')
    end

    def self.restart_all_services
      s = self.new
      Karma.logger.info('Restarting all services...')
      status = s.engine.show_all_services
      status.values.map(&:pid).each do |pid|
        Karma.logger.info("Restarting pid #{pid}...")
        s.engine.restart_service(pid)
      end
      Karma.logger.info('Done restarting services')
    end

    private ##############################

    include Karma::Helpers

    def perform
      Karma.logger.info("Started polling queue: #{Karma::Queue.incoming_queue_url}")
      queue_client.poll(queue_url: Karma::Queue.incoming_queue_url) do |msg|
        Karma.logger.debug "Got message from queue #{msg.body}"
        body = JSON.parse(msg.body).deep_symbolize_keys
        handle_message(body)
      end
    end

    # Notifies the Karma server about the current host and all Karma::Service subclasses
    def register
      Karma.logger.info('Registering services...')
      Karma.logger.info("#{service_classes.count} services found")
      service_classes.each do |cls|
        Karma.logger.info("Exporting #{cls.name}...")
        service = cls.new
        engine.export_service(service)
        service.register
      end
      Karma.logger.info('Done registering services')
    end

    def queue_client
      @@queue_client ||= Karma::Queue::Client.new
      return @@queue_client
    end

    def handle_message(message)
      begin
        Karma.logger.debug "New message arrived: #{message}"
        case message[:type]

          when Karma::Messages::ProcessCommandMessage.name
            # set the array of discovered services for validation
            Karma::Messages::ProcessCommandMessage.services = service_classes.map(&:to_s)
            msg = Karma::Messages::ProcessCommandMessage.new(message)
            Karma.error(msg.errors) unless msg.valid?
            handle_process_command(msg)

          when Karma::Messages::ProcessConfigUpdateMessage.name
            msg = Karma::Messages::ProcessConfigUpdateMessage.new(message)
            Karma.error(msg.errors) unless msg.valid?
            handle_process_config_update(msg)

          when Karma::Messages::ThreadConfigUpdateMessage.name
            msg = Karma::Messages::ThreadConfigUpdateMessage.new(message)
            Karma.error(msg.errors) unless msg.valid?
            handle_thread_config_update(msg)

          else
            Karma.error("Invalid message type: #{message[:type]} - #{message.inspect}")
        end
      rescue ::Exception => e
        Karma.logger.error "Error during message processing... #{message.inspect}"
        Karma.logger.error e.message
      end
    end

    def handle_process_command(msg)
      case msg.command
        when START_COMMAND
          cls = constantize(msg.service)
          service = cls.new
          engine.start_service(service)
        when STOP_COMMAND
          engine.stop_service(msg.pid)
        else
          Karma.logger.warn("Invalid process command: #{msg.command} - #{msg.inspect}")
      end
    end

    # keys: [:service, :type, :memory_max, :cpu_quota, :min_running, :max_running, :auto_restart, :auto_start]
    def handle_process_config_update(msg)
      cls = constantize(msg.service)
      service = cls.new
      cls.update_process_config(msg.to_config)
      engine.export_service(service)
      maintain_worker_count(service)
    end

    # TODO review if this still makes sense
    def maintain_worker_count(service)
      # stop instances
      engine.to_be_stopped_instances.each do |instance|
        Karma.logger.debug("Stop instance #{instances.name}")
        engine.stop_service(instance.pid)
      end

      # start instances
      if service.class.config_auto_start
        to_be_started_ports = all_ports_min - running_ports
        Karma.logger.debug("Running instances to be started: #{to_be_started_ports.size}")
        to_be_started_ports.each do |port|
          engine.start_service(service)
        end
      else
        Karma.logger.debug('Autostart is false')
      end
    end

    # keys: [:log_level, :num_threads]
    def handle_thread_config_update(msg)
      cls = constantize(msg.service)
      service = cls.new
      cls.update_thread_config(msg.to_config)

      running_instances = engine.running_instances_for_service(service) #keys: [:pid, :full_name, :port]
      running_instances.each do |k, instance|
        begin
          s = TCPSocket.new('127.0.0.1', instance.port)
          s.puts({ log_level: service.class.config_log_level, num_threads: service.class.config_num_threads }.to_json)
          s.close
        rescue ::Exception => e
          Karma.logger.error("Error during handle_thread_config_update: #{e.message}")
        end

      end
    end

    def check_processes
      # TODO confrontare pid per vedere se sono cambiati

    end

  end

end
