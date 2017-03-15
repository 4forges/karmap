require 'karmap/queue'

module Karma::Queue

  class LoggerNotifier < BaseNotifier
    
    def register_host
      body = {
          state: 'host-created'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    # Called by Watchdog on each Karma::Service subclass on deploy.
    def notify_created
      body = {
          state: 'created'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    def notify_start
      body = {
          state: 'started'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    def notify_running
      body = {
          state: 'running'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    def notify_stop
      body = {
          state: 'stopped'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    def notify_alive
      Karma.logger.error 'Hello karmaP... I\'m here!'
    end

  end
end
