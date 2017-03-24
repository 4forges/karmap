require 'karmap/queue'

module Karma::Queue

  class QueueNotifier < BaseNotifier

    def register_host(params)
      # TODO
    end

    def notify(message)
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, message: message.to_message) if message.present? && message.valid?
    end

    private #########################################

    def queue_client
      @@client ||= Karma::Queue::Client.new
      return @@client
    end

  end
end
