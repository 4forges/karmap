require 'karmap'

module Karma

  class Watchdog

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
      register
    end

    def main_loop
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
        Karma.logger.debug 'gracefully shutdown...'
      end
      @poller.kill
      sec = 2
      (0..sec-1).each{|i| Karma.logger.debug(sec-i);sleep 1}
    end

    def perform
      queue_client.poll(queue_url: Karma::Queue.incoming_queue_url) do |msg|
        Karma.logger.debug "MSG: #{msg}"
        begin
          body_hash = JSON.parse(msg.body).deep_symbolize_keys

          case body_hash[:type]

            when 'ProcessCommandMessage'
              Karma::Messages::ProcessCommandMessage.services = services
              msg_struct = Karma::Messages::ProcessCommandMessage.new(body_hash)
              Karma.error(msg_struct.errors) unless msg_struct.valid?
              case msg_struct.command
                when 'start'
                  engine.start_service(services[msg_struct.service])
                when 'stop'
                  engine.stop_service(services[msg_struct.service], {pid: msg_struct.pid})
                else
                  Karma.logger.warn("Invalid process command: #{msg_struct.command} - #{body_hash.inspect}")
              end

            when 'ProcessConfigUpdateMessage'
              msg = Karma::Messages::ProcessConfigUpdateMessage.new(body_hash)
              Karma.errors(msg_struct.errors) unless msg_struct.valid?
              handle_process_config_update(msg)

            when 'ThreadConfigUpdateMessage'
              msg = Karma::Messages::ThreadConfigUpdateMessage.new(body_hash)
              Karma.errors(msg_struct.errors) unless msg_struct.valid?
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

    #################################################
    # watchdog config (for export)
    #################################################
    def name
      'watchdog'
    end

    def command
      "bundle exec rails runner -e production \"o = Karma::Watchdog.new; o.perform\""
    end

    def min_running
      1
    end

    def max_running
      1
    end

    def memory_max
      nil
    end

    def cpu_quota
      nil
    end

    def auto_start
      true
    end

    def auto_restart
      true
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

    # Notifies the Karma server about the current host and all Karma::Service subclasses
    def register
      subclasses = Karma::Service.subclasses
      subclasses.each do |cls|
        s = cls.new
        engine.export_service(s)
        services[s.name] = s
        register_service(s.name)
        s.notifier.notify_created
      end
    end

    def register_service(service)
      msg = Karma::Messages::ProcessRegisterMessage.new(service: service, host: Karma::Queue.host_name, project: Karma.karma_project_id)
      queue_client.send_message2(queue_url: Karma::Queue.outgoing_queue_url, msg: msg)
    end

    def queue_client
      @@client ||= Karma::Queue::Client.new(self.class.name.to_s)
      return @@client
    end

    def handle_process_config_update(config)
      s = services[config.delete(:service)]
      s.update_process_config(config)
      engine.export_service(s)
    end

    def handle_thread_config_update(config)
      s = services[config.delete(:service)]
      s.update_thread_config(config)

      s = TCPSocket.new('127.0.0.1', s.port)
      s.puts(config.to_json)
      s.close
    end

  end

end
