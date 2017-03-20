require 'karmap'

module Karma

  class Watchdog
    LOGGER_SHIFT_AGE = 2
    LOGGER_SHIFT_SIZE = 52428800
    SHUTDOWN_SEC = 3
    START_COMMAND = 'start'
    STOP_COMMAND = 'stop'
    
    @@running_instance = nil
    @@logger = nil

    attr_accessor :services, :engine

    def initialize
      @services = {}
      @engine = case Karma.engine
                  when 'systemd'
                    Karma::Engine::Systemd.new
                  when 'string_out'
                    Karma::Engine::StringOut.new
                  when 'system_raw'
                    Karma::Engine::SystemRaw.new
                end
      @notifier = case Karma.notifier
                  when 'queue'
                    Karma::Queue::QueueNotifier.new
                  when 'log'
                    Karma::Queue::LoggerNotifier.new
                end
    end
    
    def self.run
      if @@running_instance.nil?
        @@running_instance = self.new()
        @@running_instance.run
      end
    end

    def run
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
        Watchdog::logger.debug "#{@trapped_signal} trapped"
      end
      @poller.kill
      (0..Karma::Watchdog::SHUTDOWN_SEC-1).each do |i|
        Watchdog::logger.info("Watchdog: gracefully shutdown... #{Karma::Watchdog::SHUTDOWN_SEC-i}")
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

    def port
      Karma.watchdog_port
    end

    def process_config
      return {
        min_running: 1,
        max_running: 1,
        memory_max: nil,
        cpu_quota: nil,
        auto_start: true,
        auto_restart: true,
      }
    end
    #################################################

    def self.export
      s = self.new
      s.engine.export_service(s)
    end

    def self.kill
      s = self.new
      s.engine.stop_service(s)
      # engine.remove_service(s)
    end
    
    private
    
    def self.logger
      if @@logger.nil?
        @@logger = Logger.new("log/karma-watchdog.log", shift_age = LOGGER_SHIFT_AGE, shift_size = LOGGER_SHIFT_SIZE)
        @@logger.level = Logger::INFO #Logger::DEBUG #Logger::WARN
      end
      @@logger
    end

    def perform
      queue_client.poll(queue_url: Karma::Queue.incoming_queue_url) do |msg|
        Watchdog::logger.debug "Watchdog: got message from queue #{msg.body}"
        begin
          body_hash = JSON.parse(msg.body).deep_symbolize_keys

          case body_hash[:type]

            when Karma::Messages::ProcessCommandMessage.name
              Watchdog::logger.debug services.keys
              Karma::Messages::ProcessCommandMessage.services = services.keys
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
          Watchdog::logger.error "Error during message processing... #{msg.inspect}"
          Watchdog::logger.error e.message
        end
      end
    end

    # Notifies the Karma server about the current host and all Karma::Service subclasses
    def register
      service_classes = discover_services
      service_classes.each do |cls|
        Watchdog::logger.info("Watchdog: found service class #{cls.name}")
        s = cls.new
        engine.export_service(s)
        services[s.full_name] = s
        s.register
      end
    end

    def queue_client
      @@client ||= Karma::Queue::Client.new
      return @@client
    end

    def handle_process_command(msg)
      case msg.command
        when START_COMMAND
          s = services[msg.service]
          engine.start_service(s)
        when STOP_COMMAND
          engine.stop_service(msg.pid)
        else
          Watchdog::logger.warn("Invalid process command: #{msg.command} - #{msg.inspect}")
      end
    end

    def discover_services
      Karma.services.select{|c| c.is_a?(Class) rescue false}
    end

    # keys: [:service, :type, :memory_max, :cpu_quota, :min_running, :max_running, :auto_restart, :auto_start]
    def handle_process_config_update(msg)
      s = services[msg.service]
      s.update_process_config(msg)
      engine.export_service(s)
      maintain_worker_count(s)
    end
    
    def maintain_worker_count(service)
      running_instances = engine.running_instances_for_service(service) #keys: [:pid, :full_name, :port]
      num_running = running_instances.size
      all_ports_max = ( s.port..s.port + service.max_running - 1 ).to_a
      all_ports_min = ( s.port..s.port + service.min_running - 1 ).to_a
      running_ports = running_instances.map{ |instance| instance[:port] }
      Watchdog::logger.debug("Running instances found: #{num_running}")

      # stop instances
      to_be_stopped_ports = running_ports - all_ports_max
      Watchdog::logger.debug("Running instances to be stopped: #{to_be_stopped_ports.size}")
      running_instances.each do |instance|
        engine.stop_service(instance[:pid]) if to_be_stopped_ports.include?(instance[:port])
      end
      
      # start instances
      if s.auto_start
        to_be_started_ports = all_ports_min - running_ports
        Watchdog::logger.debug("Running instances to be started: #{to_be_started_ports.size}")
        to_be_started_ports.each do |port|
          engine.start_service(service)
        end
      else
        Watchdog::logger.debug("Autostart is false")
      end
    end
    
    # keys: [:log_level, :num_threads]
    def handle_thread_config_update(msg)
      s = services[msg.service]
      s.update_thread_config(msg)

      s = TCPSocket.new('127.0.0.1', s.port)
      s.puts({ log_level: s.log_level, num_threads: s.num_threads }.to_json)
      s.close
    end

  end

end
