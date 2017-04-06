module Karma::Thread

  class SimpleTcpConfigReader

    attr_reader :config

    def initialize(default_config:, port:)
      @config = default_config || {}
      @port = port
    end

    def start
      @server = TCPServer.new('127.0.0.1', @port)
      Karma.logger.debug "#{$$} - started TCP server on port #{@port}"
      @thread = ::Thread.new do
        loop do
          client = @server.accept
          data = client.gets
          @config = JSON.parse(data).symbolize_keys
          Karma.logger.info "#{$$} - received new thread config #{@config}"
          client.close
        end
      end
    end

    def stop
      @server.close
      Karma.logger.debug "#{$$} - closed TCP server on port #{@port}"
      @thread.kill
    end

  end

end
