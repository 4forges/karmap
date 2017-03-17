require 'socket'
require 'aws-sdk'
require 'karmap/queue'

module Karma::Queue

  class Client

    def poll(queue_url:)
      Karma.logger.debug("Start polling from queue #{queue_url}")
      poller = Aws::SQS::QueuePoller.new(queue_url, { client: _client })
      poller.poll(skip_delete: true) do |msg|
        begin
          Karma.logger.debug "MSG: #{msg}"
          yield(msg)
        rescue Exception => e
          Karma.logger.error("ERROR")
        end
        Karma.logger.debug("delete_message")
        ret = poller.delete_message(msg)
        Karma.logger.debug(ret)
        # sleep(1)
      end
    end

    def send_message(queue_url:, message:)
      _client.send_message(queue_url: queue_url, message_body: message.to_json)
    end

    private ####################

    def _client
      @@client ||= Aws::SQS::Client.new(
          access_key_id: Karma.aws_access_key_id,
          secret_access_key: Karma.aws_secret_access_key,
          region: 'eu-west-1'
      )
      return @@client
    end

  end

end
