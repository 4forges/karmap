require 'logger'
require 'active_support'
require 'active_support/core_ext'
require 'karmap/configuration'
require "karma_messages"

module Karma

  extend Configuration

  define_setting :user # deploy user (required)
  define_setting :project_name # project name as string (required)
  define_setting :services, [] # managed services classes
  define_setting :karma_user_id # (required)
  define_setting :karma_project_id # (required)
  define_setting :aws_access_key_id, ENV['KARMA_AWS_ACCESS_KEY_ID']
  define_setting :aws_secret_access_key, ENV['KARMA_AWS_SECRET_ACCESS_KEY']
  define_setting :engine, 'systemd'
  define_setting :notifier, 'queue'
  define_setting :watchdog_port, 32000
  define_setting :template_folder # custom engine templates folder

  class << self
    attr_writer :logger

    def logger
      # filename = 'karmap.log'
      filename = $stdout
      @logger ||= Logger.new(filename).tap do |log|
        log.progname = self.name
      end
    end
  end

  class Exception < ::Exception; end

  def self.error(message)
    raise Karma::Exception.new(message)
  end

end

require 'karmap/engine'
require 'karmap/service'
require 'karmap/watchdog'
require 'karmap/version'
require 'karmap/queue'
require 'karmap/thread'

require 'karmap/railtie' if defined?(::Rails)
