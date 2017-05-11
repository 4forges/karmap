require 'socket'
require 'aws-sdk'
require 'karmap/queue'

module Karma::Queue

  class Client

    def poll(queue_url:)
      Karma.logger.debug{ "#{__method__}: start polling queue #{queue_url}" }
      begin
        poller = Aws::SQS::QueuePoller.new(queue_url, { client: _client })
        poller.poll(skip_delete: true) do |msg|
          begin
            Karma.logger.info{ "#{__method__} INCOMING MESSAGE: #{msg.body[:type]}" }
            Karma.logger.debug{ "#{__method__} INCOMING MESSAGE: #{msg.body}" }
            yield(msg)
          rescue ::Exception => e
            Karma.logger.error{ "#{__method__}: #{e.message}" }
          end
          poller.delete_message(msg)
        end
      rescue ::Exception => e
        Karma.logger.error{ "#{__method__}: error during poller setup - #{e.message}" }
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
