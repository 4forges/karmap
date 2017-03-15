require 'karmap/queue'

module Karma::Queue

  class BaseNotifier

    def register_host(params)
      # abstract
    end

    # Called by Watchdog on each Karma::Service subclass on deploy.
    def notify_created(params)
      # abstract
    end

    def notify_start(params)
      # abstract
    end

    def notify_running(params)
      # abstract
    end

    def notify_stop(params)
      # abstract
    end

    def notify_alive(params)
      # abstract
    end

  end

end
