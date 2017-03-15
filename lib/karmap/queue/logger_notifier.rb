require 'karmap/queue'

module Karma::Queue

  class LoggerNotifier < BaseNotifier

    def register_host(params)
      body = {
          state: 'host-created'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    # Called by Watchdog on each Karma::Service subclass on deploy.
    def notify_created(params)
      body = {
          state: 'created'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    def notify_start(params)
      body = {
          state: 'started'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    def notify_running(params)
      body = {
          state: 'running'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    def notify_stop(params)
      body = {
          state: 'stopped'
      }
      Karma.logger.debug("Outgoing message: #{body}")
    end

    def notify_alive(params)
      Karma.logger.error 'Hello karmaP... I\'m here!'
    end

  end
end
