require 'karmap'
require 'karmap/service_config'

module Karma

  class Watchdog
    include Karma::ServiceConfig

    port Karma.watchdog_port

    LOGGER_SHIFT_AGE = 2
    LOGGER_SHIFT_SIZE = 52428800
    SHUTDOWN_SEC = 0
    START_COMMAND = 'start'
    STOP_COMMAND = 'stop'

    @@service_classes = nil
    @@running_instance = nil
    @@queue_client = nil
    @@logger = nil

    attr_accessor :services, :engine

    def self.run
      @@running_instance ||= self.new
      @@running_instance.run
    end

    def initialize
      @engine = Karma.engine_class.new
      @notifier = Karma.notifier_class.new
    end

    def run
      Karma.logger.error self.class.logger
      Watchdog.logger.info("\n\n\n")
      Watchdog.logger.info('****************')
      Watchdog.logger.info('Enter run method')
      Watchdog.logger.info('****************')
      register
      @poller = ::Thread.new do
        perform
      end
      Signal.trap('INT') do
        @trapped_signal = 'INT'
        @running = false
      end
      Signal.trap('TERM') do
        @trapped_signal = 'TERM'
        @running = false
      end
      @running = true
      while @running do
        sleep 1
      end
      if @trapped_signal
        Watchdog.logger.info "Got signal #{@trapped_signal}"
        sleep 0.5
      end
      @poller.kill
      (0..Karma::Watchdog::SHUTDOWN_SEC-1).each do |i|
        Watchdog.logger.info("Gracefully shutdown... #{Karma::Watchdog::SHUTDOWN_SEC-i}")
        sleep 1
      end
    end

    #################################################
    # watchdog config (for export)
    #################################################
    def full_name
      "#{Karma.project_name}-#{name}"
    end

    def name
      'watchdog'
    end

    def command
      "bundle exec rails runner -e production \"Karma::Watchdog.run\""
    end
    #################################################

    def self.export
      s = self.new
      s.engine.export_service(s)
      status = s.engine.show_service(s)
      if status.empty?
        s.engine.start_service(s)
      else
        s.engine.restart_service(status.values[0].pid)
      end
    end

    private ##############################

    def self.logger
      if @@logger.nil?
        @@logger = Logger.new("log/karma-watchdog.log", shift_age = LOGGER_SHIFT_AGE, shift_size = LOGGER_SHIFT_SIZE)
        @@logger.level = Logger::INFO #Logger::DEBUG #Logger::WARN
      end
      @@logger
    end

    def perform
      Watchdog.logger.info('Started polling queue')
      queue_client.poll(queue_url: Karma::Queue.incoming_queue_url) do |msg|
        Watchdog.logger.debug "Got message from queue #{msg.body}"
        begin
          body_hash = JSON.parse(msg.body).deep_symbolize_keys

          case body_hash[:type]

            when Karma::Messages::ProcessCommandMessage.name
              Karma::Messages::ProcessCommandMessage.services = @@service_classes.map(&:to_s)
              msg = Karma::Messages::ProcessCommandMessage.new(body_hash)
              Karma.error(msg.errors) unless msg.valid?
              handle_process_command(msg)

            when Karma::Messages::ProcessConfigUpdateMessage.name
              msg = Karma::Messages::ProcessConfigUpdateMessage.new(body_hash)
              Karma.error(msg.errors) unless msg.valid?
              handle_process_config_update(msg)

            when Karma::Messages::ThreadConfigUpdateMessage.name
              msg = Karma::Messages::ThreadConfigUpdateMessage.new(body_hash)
              Karma.error(msg.errors) unless msg.valid?
              handle_thread_config_update(msg)

            else
              Karma.error("Invalid message: #{body_hash[:type]} - #{body_hash.inspect}")
          end
        rescue Exception => e
          Watchdog.logger.error "Error during message processing... #{msg.inspect}"
          Watchdog.logger.error e.message
        end
      end
    end

    # Notifies the Karma server about the current host and all Karma::Service subclasses
    def register
      Watchdog.logger.info('Registering services...')
      @@service_classes = discover_services
      Watchdog.logger.info("#{@@service_classes.count} services found")
      @@service_classes.each do |cls|
        Watchdog.logger.info("Found service class #{cls.name}. Exporting...")
        service = cls.new
        engine.export_service(service)
        service.register
      end
      Watchdog.logger.info('Done registering services')
    end

    def queue_client
      @@queue_client ||= Karma::Queue::Client.new
      return @@queue_client
    end

    def handle_process_command(msg)
      case msg.command
        when START_COMMAND
          s = msg.service.constantize.new
          engine.start_service(s)
        when STOP_COMMAND
          engine.stop_service(msg.pid)
        else
          Watchdog.logger.warn("Invalid process command: #{msg.command} - #{msg.inspect}")
      end
    end

    def discover_services
      Karma.services.select{|c| c.new.is_a?(Karma::Service) rescue false}
    end

    # keys: [:service, :type, :memory_max, :cpu_quota, :min_running, :max_running, :auto_restart, :auto_start]
    def handle_process_config_update(msg)
      cls = msg.service.constantize
      cls.update_process_config(msg.to_config)
      service = cls.new
      engine.export_service(service)
      maintain_worker_count(service)
    end

    def maintain_worker_count(service)
      running_instances = engine.running_instances_for_service(service) #keys: [:pid, :full_name, :port]
      num_running = running_instances.size
      all_ports_max = ( service.class.config_port..service.class.config_port + service.class.config_max_running - 1 ).to_a
      all_ports_min = ( service.class.config_port..service.class.config_port + service.class.config_min_running - 1 ).to_a
      running_ports = running_instances.values.map{ |i| i.port }
      Watchdog.logger.debug("Running instances found: #{num_running}")

      # stop instances
      to_be_stopped_ports = running_ports - all_ports_max
      Watchdog.logger.debug("Running instances to be stopped: #{to_be_stopped_ports.size}")
      running_instances.values.each do |i|
        engine.stop_service(i.pid) if to_be_stopped_ports.include?(i.port)
      end

      # start instances
      if service.class.config_auto_start
        to_be_started_ports = all_ports_min - running_ports
        Watchdog.logger.debug("Running instances to be started: #{to_be_started_ports.size}")
        to_be_started_ports.each do |port|
          engine.start_service(service)
        end
      else
        Watchdog.logger.debug('Autostart is false')
      end
    end

    # keys: [:log_level, :num_threads]
    def handle_thread_config_update(msg)
      cls = msg.service.constantize
      service = cls.new
      cls.update_thread_config(msg.to_config)

      running_instances = engine.running_instances_for_service(service) #keys: [:pid, :full_name, :port]
      running_instances.each do |instance|
        s = TCPSocket.new('127.0.0.1', i.port)
        s.puts({ log_level: service.class.config_log_level, num_threads: service.class.config_num_threads }.to_json)
        s.close
      end
    end

  end

end
