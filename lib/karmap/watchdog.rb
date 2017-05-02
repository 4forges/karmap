require 'karmap'
require 'karmap/service_config'

module Karma

  class Watchdog
    include Karma::ServiceConfig

    port Karma.watchdog_port
    timeout_stop 30

    SHUTDOWN_SEC = 0

    @@instance = nil
    @@service_classes = nil
    @@queue_client = nil

    attr_accessor :service_statuses

    def initialize
      Karma.logger.info{ "#{__method__}: environment is #{Karma.env}" }
      @service_statuses = {}
    end

    def self.command
      "bundle exec rails runner -e #{Karma.env} \"Karma::Watchdog.run\""
    end

    def self.run
      if @@instance.nil?
        @@instance = self.new
        @@instance.run
      end
    end

    def run
      Karma.logger.info{ "#{__method__}: enter" }
      register
      @poller = ::Thread.new do
        loop do
          poll_queue
          Karma.logger.error{ "#{__method__}: error during polling" }
          sleep 10
        end
      end
      Karma.logger.info{ "#{__method__}: poller started" }
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
        if (i%10).zero?
          check_services_status
        end
        if (i%60).zero?
          Karma.logger.info{ "#{__method__}: alive" }
          i = 0
        end
      end
      if @trapped_signal
        Karma.logger.info{ "#{__method__}: got signal #{@trapped_signal}" }
        sleep 0.5
      end
      @poller.kill
      (0..Karma::Watchdog::SHUTDOWN_SEC-1).each do |i|
        Karma.logger.info{ "#{__method__}: shutting down... #{Karma::Watchdog::SHUTDOWN_SEC-i}" }
        sleep 1
      end
    end

    def self.export
      Karma.engine_instance.export_service(Karma::Watchdog)
      status = Karma.engine_instance.show_service(Karma::Watchdog)
      if status.empty?
        Karma.engine_instance.start_service(Karma::Watchdog)
      else
        Karma.engine_instance.restart_service(status.values[0].pid, { service: Karma::Watchdog })
      end
    end

    def service_classes
      services_cls = Karma.services.map{|c| Karma::Helpers::constantize(c) rescue nil}.compact
      @@service_classes ||= services_cls.select{|c| c <= Karma::Service}
      @@service_classes
    end

    def self.start_all_services
      # only call register on each service. Karma server will then push a ProcessConfigUpdateMessage that
      # will trigger the starting of instances.
      s = self.new
      s.service_classes.each(&:register)
    end

    def self.stop_all_services
      status = Karma.engine_instance.show_all_services
      status.reject!{|k,v| v.name == Karma::Watchdog.full_name}
      status.values.map(&:pid).each do |pid|
        Karma.engine_instance.stop_service(pid)
      end
    end

    def self.restart_all_services
      status = Karma.engine_instance.show_all_services
      status.reject!{|k,v| v.name == Karma::Watchdog.full_name}
      status.values.map(&:pid).each do |pid|
        Karma.engine_instance.restart_service(pid)
      end
    end

    def ensure_service_instances_count(service)
      # stop instances
      Karma.engine_instance.to_be_stopped_instances(service).each do |instance|
        Karma.logger.debug{ "#{__method__}: stop instance #{instance.name}" }
        Karma.engine_instance.stop_service(instance.pid)
      end

      # start instances
      if service.config_auto_start
        Karma.engine_instance.to_be_started_ports(service).each do |port|
          Karma.logger.debug{ "#{__method__}: start new instance of #{service.name} on port #{port}" }
          Karma.engine_instance.start_service(service)
        end
      else
        Karma.logger.debug{ "#{__method__}: autostart for service #{service.name} is false" }
      end
    end

    private ##############################

    include Karma::Helpers

    def poll_queue
      Karma.logger.info{ "#{__method__}: started polling queue #{Karma::Queue.incoming_queue_url}" }
      queue_client.poll(queue_url: Karma::Queue.incoming_queue_url) do |msg|
        Karma.logger.debug{ "#{__method__}: got message from queue #{msg.body}" }
        body = JSON.parse(msg.body).deep_symbolize_keys
        handle_message(body)
      end
    end

    # Notifies the Karma server about the current host and all Karma::Service subclasses
    def register
      Karma.logger.info{ "#{__method__}: registering services..." }
      Karma.logger.info{ "#{__method__}: #{service_classes.count} services found" }
      service_classes.each do |cls|
        Karma.logger.info{ "#{__method__}: exporting #{cls.name}..." }
        Karma.engine_instance.export_service(cls)
        cls.register
      end
      Karma.logger.info{ "#{__method__}: done registering services" }
    end

    def queue_client
      @@queue_client ||= Karma::Queue::Client.new
      @@queue_client
    end

    def handle_message(message)
      begin
        Karma.logger.debug{ "#{__method__}: new message arrived #{message}" }
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
            Karma.error("Invalid message type: #{message[:type]}")
        end
      rescue ::Exception => e
        Karma.logger.error{ "#{__method__}: error processing message - #{e.message}" }
      end
    end

    def handle_process_command(msg)
      case msg.command
        when Karma::Messages::ProcessCommandMessage::COMMANDS[:start]
          cls = Karma::Helpers::constantize(msg.service)
          Karma.engine_instance.start_service(cls)
        when Karma::Messages::ProcessCommandMessage::COMMANDS[:stop]
          Karma.engine_instance.stop_service(msg.pid)
        when Karma::Messages::ProcessCommandMessage::COMMANDS[:restart]
          Karma.engine_instance.restart_service(msg.pid)
        else
          Karma.logger.warn{ "#{__method__}: invalid process command: #{msg.command} - #{msg.inspect}" }
      end
    end

    # keys: [:service, :type, :memory_max, :cpu_quota, :min_running, :max_running, :auto_restart, :auto_start]
    def handle_process_config_update(msg)
      cls = Karma::Helpers::constantize(msg.service)
      cls.set_process_config(msg.to_config)
      Karma.engine_instance.export_service(cls)
      Karma.engine_instance.export_config(cls)
      ensure_service_instances_count(cls)
    end

    # keys: [:log_level, :num_threads]
    def handle_thread_config_update(msg)
      cls = Karma::Helpers::constantize(msg.service)
      cls.set_thread_config(msg.to_config)
      Karma.engine_instance.export_config(cls)

      running_instances = Karma.engine_instance.running_instances_for_service(cls) #keys: [:pid, :full_name, :port]
      running_instances.each do |k, instance|
        begin
          connection_retries ||= 5
          s = TCPSocket.new('127.0.0.1', instance.port)
          s.puts(cls.get_thread_config.to_json)
          s.close
        rescue ::Exception => e
          if (connection_retries -= 1) > 0
            Karma.logger.warn{ "#{__method__}: #{e.message}" }
            sleep(1)
            retry
          else
            Karma.logger.error{ "#{__method__}: #{e.message}" }
          end
        end
      end
    end

    def check_services_status
      new_service_statuses = Karma.engine_instance.show_all_services
      new_service_statuses.reject!{|k,v| v.name == self.full_name}
      Karma.logger.debug{ "#{__method__}: currently #{new_service_statuses.size} running instances" }
      service_statuses.each do |instance, status|
        if new_service_statuses[instance].present?
          # notify server if pid has changed
          if new_service_statuses[instance].pid != status.pid
            service_name = Karma::Helpers::classify(status.name.sub("#{Karma.project_name}-", ''))
            cls = Karma::Helpers::constantize(service_name)
            cls.notify_status(pid: status.pid, params: {status: Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead]})
          end
        end
      end
      @service_statuses = new_service_statuses
    end

  end

end
