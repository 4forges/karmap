# frozen_string_literal: true

require 'karmap/engine'

module Karma::ConfigEngine
  class Base
    attr_reader :runtime_config

    def initialize(default_config:, options: {}); end

    def start; end

    def stop; end
  end
end
