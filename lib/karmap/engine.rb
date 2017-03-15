require 'karmap'

module Karma::Engine

  class Exception < ::Exception; end

  def self.error(message)
    raise Karma::Engine::Exception.new(message)
  end

end

require 'karmap/engine/base'
require 'karmap/engine/systemd'
require 'karmap/engine/string_out'
require 'karmap/engine/system_raw'