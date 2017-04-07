require 'karmap/queue'

module Karma::Queue

  class QueueNotifier < BaseNotifier

    def register_host(params)
      # TODO
    end

    def notify(message)
      if !message.nil? && message.valid?
        Karma.logger.info { "Sending message: #{message.to_message} to #{Karma::Queue.outgoing_queue_url}" }
        queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, message: message.to_message)
      else
        if message.nil?
          Karma.logger.info { "No message provided" } 
        else
          Karma.logger.info { "Message: #{message.to_message} is not valid" }
        end
      end
    end

    private #########################################

    def queue_client
      @@client ||= Karma::Queue::Client.new
      return @@client
    end

  end
end
