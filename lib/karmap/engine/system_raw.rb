require 'karmap/engine'
require 'sys/proctable'
include Sys

module Karma::Engine

  class SystemRaw < Base

    def location
      ''
    end

    def reload
      Karma.logger.debug("#{self.class.name} received #{__method__}")
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

    def enable_service(service, params = {})
      Karma.logger.debug("#{self.class.name} received #{__method__} for #{service.full_name}")
    end

    def start_service(service, params = {})
      ::Thread.abort_on_exception = true
      ::Thread.new do
        if !params[:port].nil? || free_ports(service).count > 0
          params[:port] ||= free_ports(service)[0]
          Karma.logger.debug "system #{service.command}, port: #{params[:port]}"
          system({"PORT" => params[:port].to_s, "KARMA_IDENTIFIER" => service.identifier(params[:port])}, service.command)
        else
          Karma.logger.debug "No free port available for service #{service.full_name}"
        end
      end
    end

    def stop_service(pid, params = {})
      ::Thread.new do
        Karma.logger.debug "system kill #{pid}"
        res = `kill #{pid}`
        Karma.logger.debug "res: #{res}"
      end
    end

    def restart_service(pid, params = {})
      stop_service(pid)
      start_service(params[:service])
    end

    def export_service(service)
      Karma.logger.debug("#{self.class.name} received #{__method__} for #{service.full_name}")
    end

    def remove_service(service)
      Karma.logger.debug("#{self.class.name} received #{__method__} for #{service.full_name}")
    end

    private ####################

    def service_status(service_key_or_pid:)
      if service_key_or_pid.is_a?(String)
        status = ProcTable.ps.select{ |p| identifier = p.environ["KARMA_IDENTIFIER"]; identifier.present? && identifier.start_with?(service_key_or_pid) }
      else
        status = ProcTable.ps.select{ |p| p.pid == service_key_or_pid.to_i }
      end
      ret = {}
      status.each do |p|
        # :name, :port, :status, :pid, :threads, :memory, :cpu
        k = p.environ["KARMA_IDENTIFIER"]
        ret[k] = Karma::Engine::ServiceStatus.new(
          p.environ["KARMA_IDENTIFIER"].split("@")[0],
          p.environ["PORT"].to_i,
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
        when 2, "R", "D"
          Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running]
        # when 'inactive', 'activating'
        #   Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:stopped]
        else
          #Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead]
          process_status
      end
    end
  end

end
