require 'karmap'
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
      @engine = Karma.engine_class.new
    end

    def run
      logger.info('Watchdog entered run method')
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
        logger.info "Got signal #{@trapped_signal}"
        sleep 0.5
      end
      @poller.kill
      (0..Karma::Watchdog::SHUTDOWN_SEC-1).each do |i|
        logger.info("Gracefully shutdown... #{Karma::Watchdog::SHUTDOWN_SEC-i}")
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
        s.engine.restart_service(status.values[0].pid)
      end
    end

    private ##############################

    def perform
      logger.info("Started polling queue: #{Karma::Queue.incoming_queue_url}")
      queue_client.poll(queue_url: Karma::Queue.incoming_queue_url) do |msg|
        logger.debug "Got message from queue #{msg.body}"
        body = JSON.parse(msg.body).deep_symbolize_keys
        handle_message(body)
      end
    end

    # Notifies the Karma server about the current host and all Karma::Service subclasses
    def register
      logger.info('Registering services...')
      @@service_classes = discover_services
      logger.info("#{@@service_classes.count} services found")
      @@service_classes.each do |cls|
        logger.info("Found service class #{cls.name}. Exporting...")
        service = cls.new
        engine.export_service(service)
        service.register
      end
      logger.info('Done registering services')
    end

    def queue_client
      @@queue_client ||= Karma::Queue::Client.new
      return @@queue_client
    end

    def logger
      @logger ||= Logger.new(
        "#{Karma.log_folder}/#{name}@#{Watchdog.config_port}.log",
        Karma::LOGGER_SHIFT_AGE,
        Karma::LOGGER_SHIFT_SIZE,
        level: Logger::INFO,
        progname: "#{name}@#{Watchdog.config_port}"
      )
      return @logger
    end

    def handle_message(message)
      begin
        case message[:type]

          when Karma::Messages::ProcessCommandMessage.name
            # set the array of discovered services for validation
            Karma::Messages::ProcessCommandMessage.services = @@service_classes.map(&:to_s)
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
        logger.error "Error during message processing... #{message.inspect}"
        logger.error e.message
      end
    end

    def handle_process_command(msg)
      case msg.command
        when START_COMMAND
          s = msg.service.constantize.new
          engine.start_service(s)
        when STOP_COMMAND
          engine.stop_service(msg.pid)
        else
          logger.warn("Invalid process command: #{msg.command} - #{msg.inspect}")
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
      logger.debug("Running instances found: #{num_running}")

      # stop instances
      to_be_stopped_ports = running_ports - all_ports_max
      logger.debug("Running instances to be stopped: #{to_be_stopped_ports.size}")
      running_instances.values.each do |i|
        engine.stop_service(i.pid) if to_be_stopped_ports.include?(i.port)
      end

      # start instances
      if service.class.config_auto_start
        to_be_started_ports = all_ports_min - running_ports
        logger.debug("Running instances to be started: #{to_be_started_ports.size}")
        to_be_started_ports.each do |port|
          engine.start_service(service)
        end
      else
        logger.debug('Autostart is false')
      end
    end

    # keys: [:log_level, :num_threads]
    def handle_thread_config_update(msg)
      cls = msg.service.constantize
      service = cls.new
      cls.update_thread_config(msg.to_config)

      running_instances = engine.running_instances_for_service(service) #keys: [:pid, :full_name, :port]
      running_instances.each do |k, instance|
        begin
          s = TCPSocket.new('127.0.0.1', instance.port)
          s.puts({ log_level: service.class.config_log_level, num_threads: service.class.config_num_threads }.to_json)
          s.close
        rescue ::Exception => e
          logger.error("Error during handle_thread_config_update: #{e.message}")
        end

      end
    end

  end

end
