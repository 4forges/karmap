require 'socket'
require 'faraday'
require 'aws-sdk'
require 'karmap/queue'

module Karma::Queue

  class Client

    attr_reader :service_name

    def initialize(service_name)
      @service_name = service_name
    end

    def poll(queue_url:)
      ENV['AWS_REGION'] = 'eu-west-1'
      ENV['AWS_ACCESS_KEY_ID'] = ENV['KARMA_AWS_ACCESS_KEY_ID']
      ENV['AWS_SECRET_ACCESS_KEY'] = ENV['KARMA_AWS_SECRET_ACCESS_KEY']
      Karma.logger.debug("Start polling from queue #{queue_url}")
      poller = Aws::SQS::QueuePoller.new(queue_url)
      poller.poll(skip_delete: true) do |msg|
        begin
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

    def send_message(queue_url:, body:)
      body.merge({
          project_id: Karma.karma_project_id,
          service_name: @service_name,
          host_name: ::Socket.gethostname.to_s,
          pid: ::Process.pid,
          # type: '',
          # state: '',
      })
      _client.send_message(queue_url: queue_url, message_body: body.to_json)
    end
    
    def send_message2(queue_url:, msg:)
      _client.send_message(queue_url: queue_url, message_body: msg.to_message.to_json)
    end

    def _client
      @@client ||= Aws::SQS::Client.new(
          access_key_id: Karma.aws_access_key_id || ENV['KARMA_AWS_ACCESS_KEY_ID'],
          secret_access_key: Karma.aws_secret_access_key || ENV['KARMA_AWS_SECRET_ACCESS_KEY'],
          region: 'eu-west-1'
      )
      return @@client
    end

  end

end