require 'karmap'

module Karma::System

  class Exception < ::Exception; end

  def self.error(message)
    raise Karma::Engine::Exception.new(message)
  end

end

require 'karmap/system/portable_poller'
require 'karmap/system/process'
require 'karmap/system/slash_proc_poller'
