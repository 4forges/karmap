# frozen_string_literal: true

require 'karmap/engine'
require 'sys/proctable'
include Sys

module Karma::Engine
  class SystemRaw < Base
    START_TIMEOUT_SECONDS = 20.seconds

    def location
      Karma.home_path.to_s
    end

    def show_service(service)
      service_status(service_key_or_pid: "#{service.full_name}@") || []
    end

    def show_service_by_pid(pid)
      service_status(service_key_or_pid: pid.to_i) || []
    end

    def show_all_services
      service_status(service_key_or_pid: "#{project_name}-") || []
    end

    def start_service(service, params = {})
      pid = nil
      free_ports = free_ports(service)
      if free_ports.count > 0
        params[:port] = free_ports[0]
        clean_old_file(service: service, port: params[:port])
        Karma.logger.debug { "#{__method__}: starting '#{service.command}', port: #{params[:port]}" }
        environment_vars = {
          'PORT' => params[:port].to_s,
          'KARMA_IDENTIFIER' => service.generate_instance_identifier(port: params[:port]),
          'KARMA_ENV' => Karma.env,
          'KARMA_PROJECT_ID' => Karma.karma_project_id,
          'KARMA_USER_ID' => Karma.karma_user_id,
          'KARMA_AWS_USER_ACCESS_KEY' => Karma.aws_access_key_id,
          'KARMA_AWS_USER_SECRET_ACCESS_KEY' => Karma.aws_secret_access_key,
          'KARMA_ENGINE' => Karma.engine # 'system_raw'
        }
        pid = spawn(environment_vars, service.command)
        Process.detach(pid)
        started_at = Time.now
        instance_identifier = environment_vars['KARMA_IDENTIFIER']
        filename = pid_filename(identifier: instance_identifier)
        while !File.exists?(filename)
          Karma.logger.debug { "Waiting starting pid #{pid} - file #{filename}" }
          sleep 1
          if (Time.now - started_at) > START_TIMEOUT_SECONDS
            `kill #{pid}` rescue '' # TODO kill process only if running
            message = "Unable to start service #{instance_identifier}"
            raise message
          end
        end
        Karma.logger.debug { "#{__method__}: started" }
      end
      pid
    end

    def stop_service(pid, params = {})
      Karma.logger.debug{ "#{__method__}: killing #{pid}" }
      res = `kill #{pid}`
      instance_identifier = get_instance_identifier_from_pid(pid: pid)
      filename = pid_filename(identifier: instance_identifier)
      Karma.logger.debug { File.exists?(filename) }
      started_at = Time.now
      while File.exists?(filename)
        Karma.logger.debug { "Waiting stopping pid #{pid} - file #{filename}" }
        sleep 1
        if (Time.now - started_at) > START_TIMEOUT_SECONDS
          message = "Unable to stop service #{instance_identifier}"
          raise message
        end
      end
      Karma.logger.debug { "#{__method__}: kill result #{res}" }
    end

    def restart_service(pid, params = {})
      stop_service(pid, params)
      start_service(params[:service])
    end

    # after start callback to create pid file
    def after_start_service(service_instance, _params = {})
      instance_identifier = service_instance.instance_identifier
      filename = pid_filename(identifier: instance_identifier)
      File.write(filename, Process.pid)
    end

    # after stop callback to remove pid file
    def after_stop_service(service_instance, _params = {})
      instance_identifier = service_instance.instance_identifier
      filename = pid_filename(identifier: instance_identifier)
      FileUtils.rm_r(filename) rescue ''
    end

    private

    def service_status(service_key_or_pid:)
      if service_key_or_pid.is_a?(String)
        status = ProcTable.ps.select do |p|
          identifier = p.environ['KARMA_IDENTIFIER']
          identifier.present? && identifier.start_with?(service_key_or_pid)
        end
      else
        status = ProcTable.ps.select { |p| p.pid == service_key_or_pid.to_i }
      end
      ret = {}
      status.each do |p|
        process = Karma::System::Process.new(p.pid)
        # :name, :port, :status, :pid, :threads, :memory, :cpu
        k = p.environ['KARMA_IDENTIFIER']
        ret[k] = Karma::Engine::ServiceStatus.new(
          (p.environ['KARMA_IDENTIFIER']||'').split('@')[0],
          p.environ['PORT'].to_i,
          to_karma_status(p.state),
          p.pid,
          -1, # tasks
          process.memory,
          process.percent_cpu
        )
      end
      ret
    end

    # see: https://unix.stackexchange.com/questions/18474/what-does-this-process-stat-indicates
    # D Uninterruptible sleep (usually IO)
    # R Running or runnable (on run queue)
    # S Interruptible sleep (waiting for an event to complete)
    # T Stopped, either by a job control signal or because it is being traced.
    # W paging (not valid since the 2.6.xx kernel)
    # X dead (should never be seen)
    # Z Defunct ("zombie") process, terminated but not reaped by its parent.
    # and the additional characters are:
    #
    # < high-priority (not nice to other users)
    # N low-priority (nice to other users)
    # L has pages locked into memory (for real-time and custom IO)
    # s is a session leader
    # l is multi-threaded (using CLONE_THREAD, like NPTL pthreads do)
    # + is in the foreground process group
    def to_karma_status(process_status)
      case process_status
      when 'D', 'R', 'S'
        Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running]
      when 'T'
        Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:stopped]
      when 'X', 'Z'
        Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead]
      else
        Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:stopped]
      end
    end

    def get_instance_identifier_from_pid(pid:)
      show_service_by_pid(pid).keys.first
    end

    ### pid file utility methods ###

    # returns filename from service identifier
    def pid_filename(identifier:)
      filename = File.join(location, identifier.to_s + '.pid')
    end

    def clean_old_file(service:, port:)
      instance_identifier = service.generate_instance_identifier(port: port)
      file_path = pid_filename(identifier: instance_identifier)
      if File.exists?(file_path)
        Karma.logger.debug{ "#{__method__}: removing old pid file" }
        FileUtils.rm_r(file_path) rescue ''
      else
        Karma.logger.debug{ "#{__method__}: no old file to remove" }
      end
    end
  end
end
