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
  LOGGER_SHIFT_SIZE = 50 * 1024 * 1024

  define_setting :home_path # user home folder path without trailing slash, ie. /home/extendi (required)
  define_setting :project_name # project name as string (required)
  define_setting :services, [] # managed services classes (required)
  define_setting :karma_base_queue_url # (required)
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
  define_setting :config_engine, 'file'
  define_setting :notifier, 'queue'
  define_setting :watchdog_port, 32_000
  define_setting :version_file_path # file to update for version check
  define_setting :log_folder, 'log' # custom log folder
  define_setting :template_folder # custom engine templates folder

  class << self
    def logger=(val)
      @overridden = val
      @instance_logger = val
      Karma::Messages.logger = val
      ::Thread.current[:logger] = val
    end

    def logger
      (@overridden.present? rescue false) ? @overridden : (is_thread? ? thread_logger : instance_logger)
    end

    def is_thread?
      ::Thread.current[:thread_index].present?
    end

    def thread_logger
      ::Thread.current[:logger] ||= init_thread_logger
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

    def service_classes
      if !defined?(@@service_classes)
        @@service_classes = Karma.services.map do |c|
          klass = (Karma::Helpers.constantize(c) rescue nil)
          klass.present? && klass <= Karma::Service ? klass : nil
        end.compact
        @@service_classes ||= []
      end
      @@service_classes
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
          progname: name
        )
      else
        ret_logger = Logger.new($stdout).tap do |log|
          log.progname = name
        end
      end
      Karma::Messages.logger = ret_logger
      ret_logger.info { "#{__method__} done (#{ret_logger.object_id})" }
      ret_logger.debug { "#{__method__} instance_identifier: #{instance_identifier}" }
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
          progname: name
        )
      else
        ret_logger = Logger.new($stdout).tap do |log|
          log.progname = name
        end
      end
      ret_logger.info { "#{__method__} done (#{ret_logger.object_id})" }
      ret_logger.debug { "#{__method__} instance_identifier: #{instance_identifier}" }
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

    def config_engine_class
      case Karma.config_engine
      when 'tcp'
        Karma::ConfigEngine::SimpleTcp
      when 'file'
        Karma::ConfigEngine::File
      end
    end

    def reset_engine_instance
      # Reset the singleton class. Used in tests.
      @engine_instance = nil
    end

    def error(message)
      raise Karma::Exception.new(message)
    end
  end

  class Exception < ::Exception
  end
end

class Logger
  def format_message(severity, timestamp, progname, msg)
    method_name = (caller[3][/`.*'/][1..-2] rescue 'method_name').truncate(15).ljust(15)
    "#{severity[0]}, [#{timestamp.strftime('%Y-%m-%d %H:%M:%S.%6N')} ##{Process.pid}], #{method_name}: #{msg}\n"
  end
end

require 'karmap/engine'
require 'karmap/system'
require 'karmap/service'
require 'karmap/watchdog'
require 'karmap/version'
require 'karmap/queue'
require 'karmap/thread'
require 'karmap/config_engine'
require 'karmap/file_helper'

require 'karmap/railtie' if defined?(::Rails)
