require 'karmap/queue'

module Karma::Queue

  class LoggerNotifier < BaseNotifier

    def register_host(params)
      notify(params)
    end

    def notify(message)
      Karma.logger.debug{ "#{__method__}: outgoing message - #{message}" }
    end

  end
end
