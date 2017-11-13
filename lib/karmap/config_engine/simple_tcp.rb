module Karma::ConfigEngine

  class SimpleTcp < Base


    def initialize(default_config:, options: {})
      @runtime_config = default_config
      @port = options[:port]
    end

    def start
      @server = TCPServer.new('127.0.0.1', @port)
      Karma.logger.debug { "started TCP server on port #{@port}" }
      @thread = ::Thread.new do
        loop do
          begin
            client = @server.accept
            data = client.gets
            @runtime_config = JSON.parse(data).symbolize_keys
            Karma.logger.info { "received new thread config #{@runtime_config}" }
          rescue IOError => e
            Karma.logger.error { e }
          ensure
            client.close if client
          end
        end
      end
    end

    def stop
      @server.close
      Karma.logger.debug { "closed TCP server on port #{@port}" }
      @thread.kill
    end
    
    def self.send_config(cls, options = {})
      running_ports = Karma.engine_instance.running_instances_for_service(cls).values.map(&:port)
      running_ports.each do |port|
        Karma.logger.debug { "Updating config for serice #{cls}@#{port}" }
        connection_retries = 5
        begin
          instance_config = cls.get_process_config.to_json
          s = TCPSocket.new('127.0.0.1', port)
          s.puts(instance_config)
          s.close
        rescue ::Exception => e
          if (connection_retries -= 1) > 0
            Karma.logger.warn{ "#{__method__}: #{e.message} -> retry: #{connection_retries}" }
            sleep(1)
            retry
          else
            Karma.logger.error{ "#{__method__}: #{e.message} -> no more retry left" }
          end
        end
      end
    end

  end

end
