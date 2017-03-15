require 'karmap/queue'

module Karma::Queue

  class QueueNotifier < BaseNotifier

    def register_host(params)
      body = {
          state: 'host-created'
      }
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: body)
    end

    # Called by Watchdog on each Karma::Service subclass on deploy.
    def notify_created(params)
      body = {
          state: 'created'
      }
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: body)
    end

    def notify_start(params)
      body = {
          state: 'started'
      }
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: body)
    end

    def notify_running(params)
      msg = StatusUpdateMessage.new(params)
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: msg.to_message)
    end

    def notify_stop(params)
      body = {
          state: 'stopped'
      }
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: body)
    end

    def notify_alive(params)
      Karma.logger.error 'Hello karmaP... I\'m here!'
    end

    private #########################################

    def queue_client
      @@client ||= Karma::Queue::Client.new(@parent.class.name.to_s)
      return @@client
    end

  end
end
