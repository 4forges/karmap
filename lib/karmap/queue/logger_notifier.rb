require 'karmap/queue'

module Karma::Queue

  class LoggerNotifier < BaseNotifier

    def register_host(params)
      Karma.logger.debug("Outgoing message: #{params}")
    end

    def notify_created(params)
      Karma.logger.debug("Outgoing message: #{params}")
    end

    def notify_status(process_status_update_message)
      Karma.logger.debug("Outgoing message: #{process_status_update_message.to_message}")
    end

  end
end
