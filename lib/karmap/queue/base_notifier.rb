require 'karmap/queue'

module Karma::Queue

  class BaseNotifier

    def register_host
      # abstract
    end

    # Called by Watchdog on each Karma::Service subclass on deploy.
    def notify_created
      # abstract
    end

    def notify_start
      # abstract
    end

    def notify_running
      # abstract
    end

    def notify_stop
      # abstract
    end

    def notify_alive
      # abstract
    end

  end

end
