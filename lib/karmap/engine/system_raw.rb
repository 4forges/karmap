require 'byebug'
require 'karmap/engine'
require 'sys/proctable'
include Sys

module Karma::Engine

  class SystemRaw < Base
    START_TIMEOUT_SECONDS = 20.seconds

    def after_start_service(service_instance, params = {})
      file_path = pid_filename(identifier: service_instance.instance_identifier || "#{service_instance.class.full_name}@#{service_instance.instance_port}")
      File.write(file_path, Process.pid)
    end

    def after_stop_service(service_instance, params = {})
      FileUtils.rm_r(pid_filename(identifier: service_instance.instance_identifier)) rescue ''
    end
    
    def pid_filename(identifier: )
      filename = File.join(location, identifier.to_s + '.pid')
    end
    
    def remove_pid_file
    end
    
    def location
      "#{Karma.home_path}"
    end
    
    def show_service(service)
      service_status(service_key_or_pid: "#{service.full_name}@")
    end

    def show_service_by_pid(pid)
      service_status(service_key_or_pid: pid.to_i)
    end

    def show_all_services
      service_status(service_key_or_pid: "#{project_name}-")
    end
    
    def clean_old_file(service: , port:)
      instance_identifier = service.generate_instance_identifier(port: port)
      file_path = pid_filename(identifier: instance_identifier)
      if File.exists?(file_path)
        Karma.logger.debug{ "#{__method__}: removing old pid file" }
        FileUtils.rm_r(file_path) rescue ''
      else
        Karma.logger.debug{ "#{__method__}: no old file to remove" }
      end
    end
    
    def start_service(service, params = {})
      pid = nil
      if free_ports(service).count > 0
        params[:port] = free_ports(service)[0]
        clean_old_file(service: service, port: params[:port])
        Karma.logger.debug{ "#{__method__}: starting '#{service.command}', port: #{params[:port]}" }
        environment_vars = Hash.new.tap do |h|
          h['PORT'] = params[:port].to_s
          h['KARMA_IDENTIFIER'] = service.generate_instance_identifier(port: params[:port])
          h['KARMA_ENV'] = Karma.env
          h['KARMA_PROJECT_ID'] = Karma.karma_project_id
          h['KARMA_USER_ID'] = Karma.karma_user_id
          h['KARMA_AWS_USER_ACCESS_KEY'] = Karma.aws_access_key_id
          h['KARMA_AWS_USER_SECRET_ACCESS_KEY'] = Karma.aws_secret_access_key
          h['KARMA_ENGINE'] = 'system_raw'
        end
        pid = spawn(environment_vars, service.command)
        Process.detach(pid)
        started_at = Time.now
        while !File.exists?(pid_filename(identifier: environment_vars['KARMA_IDENTIFIER'])) do
          Karma.logger.debug { "Waiting starting pid #{pid} - file #{pid_filename(identifier: environment_vars['KARMA_IDENTIFIER'])}" }
          sleep 1
          if (Time.now - started_at) > START_TIMEOUT_SECONDS
            `kill #{pid}`
            message = "Unable to start service #{environment_vars['KARMA_IDENTIFIER']}" 
            raise message
          end
        end
        Karma.logger.debug{ "#{__method__}: started" }
      end
      pid
    end
    
    def get_instance_identifier_from_pid(pid:)
      show_service_by_pid(pid).keys.first
    end

    def stop_service(pid, params = {})
      Karma.logger.debug{ "#{__method__}: killing #{pid}" }
      res = `kill #{pid}`
      instance_identifier = get_instance_identifier_from_pid(pid: pid)
      filename = pid_filename(identifier: instance_identifier)
      Karma.logger.debug { File.exists?(filename) }
      started_at = Time.now
      while File.exists?(filename) do
        Karma.logger.debug { "Waiting stopping pid #{pid} - file #{filename}" }
        sleep 1
        if (Time.now - started_at) > START_TIMEOUT_SECONDS
          message = "Unable to stop service #{instance_identifier}" 
          raise message
        end
      end
      Karma.logger.debug{ "#{__method__}: kill result #{res}" }
    end

    def restart_service(pid, params = {})
      stop_service(pid, params)
      start_service(params[:service])
    end

    private ####################

    def service_status(service_key_or_pid:)
      if service_key_or_pid.is_a?(String)
        status = ProcTable.ps.select{ |p| identifier = p.environ['KARMA_IDENTIFIER']; identifier.present? && identifier.start_with?(service_key_or_pid) }
      else
        status = ProcTable.ps.select{ |p| p.pid == service_key_or_pid.to_i }
      end
      ret = {}
      status.each do |p|
        # :name, :port, :status, :pid, :threads, :memory, :cpu
        k = p.environ['KARMA_IDENTIFIER']
        ret[k] = Karma::Engine::ServiceStatus.new(
          (p.environ['KARMA_IDENTIFIER']||'').split('@')[0],
          p.environ['PORT'].to_i,
          to_karma_status(p.state),
          p.pid,
          -1,
          -1,
          -1
        )
      end
      return ret
    end

    def to_karma_status(process_status)
      case process_status
        when 2, 'R', 'D', 'S'
          Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running]
        else
          Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:stopped]
      end
    end
  end

end
