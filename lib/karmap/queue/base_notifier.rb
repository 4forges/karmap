require 'karmap/queue'

module Karma::Queue

  class BaseNotifier

    def register_host(params)
      # abstract
    end

    def notify(message)
      # abstract
    end

  end

end
