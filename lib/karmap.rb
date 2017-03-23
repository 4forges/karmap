require 'logger'
require 'active_support'
require 'active_support/core_ext'
require 'karma_messages'
require 'karmap/configuration'

module Karma

  extend Configuration

  LOGGER_SHIFT_AGE = 2
  LOGGER_SHIFT_SIZE = 52428800

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
      # filename = $stdout
      filename = 'karma.log'
      @logger ||= Logger.new(filename, Karma::LOGGER_SHIFT_AGE, Karma::LOGGER_SHIFT_SIZE, level: Logger::DEBUG, progname: self.name)
    end

    def notifier_class
      case Karma.notifier
        when 'queue'
          Karma::Queue::QueueNotifier
        when 'logger'
          Karma::Queue::LoggerNotifier
      end
    end

    def engine_class
      case Karma.engine
        when 'systemd'
          Karma::Engine::Systemd
        when 'logger'
          Karma::Engine::Logger
        when 'system_raw'
          Karma::Engine::SystemRaw
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
