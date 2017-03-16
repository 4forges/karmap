require 'karmap/queue'

module Karma::Queue

  class QueueNotifier < BaseNotifier

    def register_host(params)
      # TODO
    end

    def notify_created(params)
      # TODO
    end

    def notify_status(process_status_update_message)
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, message: process_status_update_message)
    end

    private #########################################

    def queue_client
      @@client ||= Karma::Queue::Client.new
      return @@client
    end

  end
end
