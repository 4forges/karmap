require 'karmap'
require 'socket'
require 'digest'

module Karma::Queue

  class Exception < ::Exception; end

  def self.error(message)
    raise Karma::Queue::Exception.new(message)
  end

  def self.base_queue_url
    'https://sqs.eu-west-1.amazonaws.com/282806688548'
  end

  def self.outgoing_queue_url
    "#{base_queue_url}/#{Karma.karma_user_id}"
  end

  def self.host_name
    ::Socket.gethostname.to_s
  end
  
  def self.incoming_queue_url
    s = "#{Karma.karma_user_id}-#{Karma.karma_project_id}-#{host_name}"
    Karma.logger.debug(s)
    "#{base_queue_url}/#{::Digest::MD5.hexdigest(s)}"
  end

end

require 'karmap/queue/client'
require 'karmap/queue/base_notifier'
require 'karmap/queue/queue_notifier'
require 'karmap/queue/logger_notifier'