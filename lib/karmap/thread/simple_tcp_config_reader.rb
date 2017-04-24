module Karma::Thread

  class SimpleTcpConfigReader

    attr_reader :runtime_config

    def initialize(default_config:, port:)
      @config = default_config || {}
      @port = port
    end

    def start
      @server = TCPServer.new('127.0.0.1', @port)
      Karma.logger.debug { "#{$$} - started TCP server on port #{@port}" }
      @thread = ::Thread.new do
        loop do
          begin
            client = @server.accept
            data = client.gets
            @runtime_config = JSON.parse(data).symbolize_keys
            Karma.logger.info { "#{$$} - received new thread config #{@runtime_config}" }
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
      Karma.logger.debug { "#{$$} - closed TCP server on port #{@port}" }
      @thread.kill
    end

  end

end
