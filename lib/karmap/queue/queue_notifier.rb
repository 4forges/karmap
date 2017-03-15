require 'karmap/queue'

module Karma::Queue

  class QueueNotifier < BaseNotifier

    def register_host
      body = {
          state: 'host-created'
      }
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: body)
    end

    # Called by Watchdog on each Karma::Service subclass on deploy.
    def notify_created
      body = {
          state: 'created'
      }
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: body)
    end

    def notify_start
      body = {
          state: 'started'
      }
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: body)
    end

    def notify_running
      body = {
          state: 'running'
      }
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: body)
    end

    def notify_stop
      body = {
          state: 'stopped'
      }
      queue_client.send_message(queue_url: Karma::Queue.outgoing_queue_url, body: body)
    end

    def notify_alive
      Karma.logger.error 'Hello karmaP... I\'m here!'
    end

    private #########################################

    def queue_client
      @@client ||= Karma::Queue::Client.new(@parent.class.name.to_s)
      return @@client
    end

  end
end
