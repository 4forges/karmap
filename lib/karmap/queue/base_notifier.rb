require 'karmap/queue'

module Karma::Queue

  class BaseNotifier

    # Called by Watchdog on deploy.
    def register_host(params)
      # abstract
    end

    # Called by Watchdog on each Karma::Service subclass on deploy.
    def notify_created(params)
      # abstract
    end

    # Called by each service instance when starting/running/stopping.
    def notify_status(process_status_update_message)
      # abstract
    end

  end

end
