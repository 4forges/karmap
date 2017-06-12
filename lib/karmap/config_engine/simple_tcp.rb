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
      # push configuration to all running threads
      running_instances = Karma.engine_instance.running_instances_for_service(cls) #keys: [:pid, :full_name, :port]
      running_instances.each do |k, instance|
        begin
          connection_retries ||= 5
          s = TCPSocket.new('127.0.0.1', instance.port)
          s.puts(cls.get_process_config.to_json)
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

  end

end
