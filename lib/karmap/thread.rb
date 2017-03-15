require 'karmap'

module Karma::Thread

  class Exception < ::Exception; end

  def self.error(message)
    raise Karma::Thread::Exception.new(message)
  end

end

require 'karmap/thread/managed_thread'
require 'karmap/thread/thread_pool'
require 'karmap/thread/simple_tcp_config_reader'
require 'karmap/thread/fake_config_reader'