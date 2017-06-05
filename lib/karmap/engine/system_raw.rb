require 'karmap/engine'
require 'sys/proctable'
include Sys

module Karma::Engine

  class SystemRaw < Base

    def show_service(service)
      service_status(service_key_or_pid: "#{service.full_name}@")
    end

    def show_service_by_pid(pid)
      service_status(service_key_or_pid: pid.to_i)
    end

    def show_all_services
      service_status(service_key_or_pid: "#{project_name}-")
    end

    def start_service(service, params = {})
      ::Thread.abort_on_exception = true
      if free_ports(service).count > 0
        params[:port] = free_ports(service)[0]
        Karma.logger.debug{ "#{__method__}: starting '#{service.command}', port: #{params[:port]}" }
        environment_vars = Hash.new.tap do |h|
          h['PORT'] = params[:port].to_s
          h['KARMA_IDENTIFIER'] = service.generate_instance_identifier(port: params[:port])
          h['KARMA_ENV'] = Karma.env
          h['KARMA_PROJECT_ID'] = Karma.karma_project_id
          h['KARMA_USER_ID'] = Karma.karma_user_id
          h['KARMA_AWS_USER_ACCESS_KEY'] = Karma.aws_access_key_id
          h['KARMA_AWS_USER_SECRET_ACCESS_KEY'] = Karma.aws_secret_access_key
        end
        fork do
          environment_vars.each do |k, v|
            ENV[k] = v
          end
          exec service.command
        end
      end
    end

    def stop_service(pid, params = {})
      ::Thread.new do
        Karma.logger.debug{ "#{__method__}: killing #{pid}" }
        res = `kill #{pid}`
        Karma.logger.debug{ "#{__method__}: kill result #{res}" }
      end
    end

    def restart_service(pid, params = {})
      `kill #{pid}`
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
          p.environ['KARMA_IDENTIFIER'].split('@')[0],
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
        when 2, 'R', 'D'
          Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running]
        else
          Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:stopped]
      end
    end
  end

end
