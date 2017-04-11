require 'karmap/queue'

module Karma::Queue

  class QueueNotifier < BaseNotifier

    def register_host(params)
      # TODO
    end

    def notify(message)
      if message.nil?
        Karma.logger.warn{ "#{__method__}: empty message" }
      elsif !message.valid?
        Karma.logger.warn{ "#{__method__}: message is not valid - #{message.to_message}" }
      else
        Karma.logger.debug{ "#{__method__}: outgoing message - #{message}" }
        queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, message: message.to_message)
      end
    end

    private #########################################

    def queue_client
      @@client ||= Karma::Queue::Client.new
      return @@client
    end

  end
end
