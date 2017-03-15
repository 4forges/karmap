module Karma::Thread

  class SimpleTcpConfigReader

    attr_reader :config

    def initialize(default_config)
      @config = default_config
    end

    def start
      port = ENV['PORT'] || 8899 # port comes from systemd unit file environment, 8899 is for testing
      @server = TCPServer.new('127.0.0.1', port)
      Karma.logger.info "Started TCP server on port #{port}"
      @thread = ::Thread.new do
        loop do
          client = @server.accept
          data = client.gets
          @config = JSON.parse(data).symbolize_keys
          Karma.logger.debug "RECEIVED NEW CONFIG >>>>>>>>>>>>>>>> #{@config}"
          client.close
        end
      end
    end

    def stop
      @server.close
      @thread.kill
    end

  end

end
