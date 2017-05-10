Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8


require 'logger'
require 'active_support'
require 'active_support/core_ext'
require 'karma_messages'
require 'karmap/configuration'
require 'karmap/helpers'

module Karma

  extend Configuration

  LOGGER_SHIFT_AGE = 2
  LOGGER_SHIFT_SIZE = 50*1024*1024

  define_setting :home_path # user home folder path without trailing slash, ie. /home/extendi (required)
  define_setting :project_name # project name as string (required)
  define_setting :services, [] # managed services classes (required)
  define_setting :karma_user_id # (required)
  define_setting :karma_project_id # (required)
  define_setting :aws_access_key_id # (required)
  define_setting :aws_secret_access_key # (required)
  if defined?(::Rails)
    define_setting :env, Rails.env
  else
    define_setting :env # (required)
  end
  define_setting :engine, 'systemd'
  define_setting :notifier, 'queue'
  define_setting :watchdog_port, 32000
  define_setting :version_file_path # file to update for version check
  define_setting :log_folder, 'log' # custom log folder
  define_setting :template_folder # custom engine templates folder

  class << self

    attr_writer :logger

    def logger
      if ::Thread.current[:thread_index].present?
        ::Thread.current[:logger] ||= init_thread_logger
      else
        instance_logger
      end
    end

    def instance_logger
      @instance_logger ||= init_logger
    end

    def instance_log_prefix
      instance_identifier
    end

    def instance_identifier
      ENV['KARMA_IDENTIFIER']
    end

    def init_logger
      ret_logger = nil
      if instance_identifier
        filename = "#{Karma.log_folder}/#{instance_log_prefix}.log"
        ret_logger = Logger.new(
          filename,
          Karma::LOGGER_SHIFT_AGE,
          Karma::LOGGER_SHIFT_SIZE,
          level: Logger::DEBUG,
          progname: self.name
        )
      else
        ret_logger = Logger.new($stdout).tap do |log|
          log.progname = self.name
        end
      end
      Karma::Messages.logger = ret_logger
      ret_logger.info { "Logger initialized (#{ret_logger.object_id})" }
      ret_logger.debug { "instance_identifier is defined: #{instance_identifier.present?}" }
      ret_logger
    end

    def init_thread_logger
      ret_logger = nil
      if instance_identifier
        filename = "#{Karma.log_folder}/#{instance_log_prefix}-#{::Thread.current[:thread_index]}.log"
        ret_logger = Logger.new(
          filename,
          Karma::LOGGER_SHIFT_AGE,
          Karma::LOGGER_SHIFT_SIZE,
          level: Logger::DEBUG,
          progname: self.name
        )
      else
        ret_logger = Logger.new($stdout).tap do |log|
          log.progname = self.name
        end
      end
      ret_logger.info { "Logger initialized (#{ret_logger.object_id})" }
      ret_logger.debug { "instance_identifier is defined: #{instance_identifier.present?}" }
      ret_logger
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

    def notifier_instance
      @notifier_instance ||= Karma.notifier_class.new
    end

    def engine_instance
      @engine_instance ||= Karma.engine_class.new
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
