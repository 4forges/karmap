require 'karmap'

module Karma

  class Watchdog
    SHUTDOWN_SEC = 3
    START_COMMAND = 'start'
    STOP_COMMAND = 'stop'
    DEFAULT_PORT = 32000

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

    def main_loop
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
        Karma.logger.debug "#{@trapped_signal} trapped"
      end
      @poller.kill
      (0..Karma::Watchdog::SHUTDOWN_SEC-1).each do |i|
        Karma.logger.debug("Watchdog: gracefully shutdown... #{Karma::Watchdog::SHUTDOWN_SEC-i}")
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
      "bundle exec rails runner -e production \"Karma::Watchdog.new.main_loop\""
    end

    def port
      Karma::Watchdog::DEFAULT_PORT # TODO
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

    def perform
      queue_client.poll(queue_url: Karma::Queue.incoming_queue_url) do |msg|
        Karma.logger.debug "Watchdog: got message from queue #{msg.body}"
        begin
          body_hash = JSON.parse(msg.body).deep_symbolize_keys

          case body_hash[:type]

            when Karma::Messages::ProcessCommandMessage.name
              Karma.logger.debug services.keys
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
          Karma.logger.error "Error during message processing... #{msg.inspect}"
          Karma.logger.error e.message
        end
      end
    end

    # Notifies the Karma server about the current host and all Karma::Service subclasses
    def register
      service_classes = discover_services
      service_classes.each do |cls|
        Karma.logger.info("Watchdog: found service class #{cls.name}")
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
          Karma.logger.warn("Invalid process command: #{msg.command} - #{msg.inspect}")
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
      
      running_instances = engine.running_instances_for_service(s) #keys: [:pid, :full_name, :port]
      num_running = running_instances.size
      all_ports_max = ( s.port..s.port + msg.max_running - 1 ).to_a
      all_ports_min = ( s.port..s.port + msg.min_running - 1 ).to_a
      running_ports = running_instances.map{ |instance| instance[:port] }
      Karma.logger.debug("Running instances found: #{num_running}")

      # stop instances
      to_be_stopped_ports = running_ports - all_ports_max
      Karma.logger.debug("Running instances to be stopped: #{to_be_stopped_ports.size}")
      running_instances.each do |instance|
        engine.stop_service(instance[:pid]) if to_be_stopped_ports.include?(instance[:port])
      end
      
      # start instances
      to_be_started_ports = all_ports_min - running_ports
      Karma.logger.debug("Running instances to be started: #{to_be_started_ports.size}")
      to_be_started_ports.each do |port|
        engine.start_service(s)
      end

    end
    
    def maintain_worker_count
      # spawn_missing_workers
      # worker_loop
    end
      
    def handle_thread_config_update(msg)
      s = services[msg.service]
      s.update_thread_config(msg)

      s = TCPSocket.new('127.0.0.1', s.port)
      s.puts(msg.to_json)
      s.close
    end

  end

end
