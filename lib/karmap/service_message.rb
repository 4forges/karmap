module Karma
  module ServiceMessage

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      
      def send_to_queue(msg)
        queue_client = Karma::Queue::Client.new
        Karma.logger.info("Sending message to queue: #{Karma::Queue.incoming_queue_url}")
        Karma.logger.info("message: #{msg.to_message}")
        queue_client.send_message(queue_url: Karma::Queue.incoming_queue_url, message: msg.to_message)
      end
      
      def start
        msg = Karma::Messages::ProcessCommandMessage.new(service: self.new.class.name, command: 'start')
        send_to_queue(msg)
      end

      def stop
        msg = Karma::Messages::ProcessCommandMessage.new(service: self.new.class.name, command: 'stop')
        send_to_queue(msg)
      end

      def process_config_update(config)
        h = self.to_process_config.merge!(config).merge!(service: self.new.class.name)
        msg = Karma::Messages::ProcessConfigUpdateMessage.new(h)
        send_to_queue(msg)
      end

      def thread_config_update(config)
        h = self.to_thread_config.merge!(config).merge!(service: self.new.class.name)
        msg = Karma::Messages::ThreadConfigUpdateMessage.new(h)
        send_to_queue(msg)
      end
      
    end

  end
end
