require 'karmap/engine'
require 'sys/proctable'
include Sys

module Karma::Engine

  class SystemRaw < Base

    def location
      ""
    end

    def reload
      Karma.logger.debug("Karma::Engine received #{__method__}")
    end

    def show_service(service)
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def show_service_by_pid(pid)
      t = ProcTable.ps(pid)
      Karma::Engine::ServiceStatus.new(
        t.environ["KARMA_IDENTIFIER"],
        t.environ["PORT"],
        [0, 1, :running][t.status],
        t.pid,
        -1,
        -1,
        -1,
      )
    end

    def show_all_services
      Karma.logger.debug("Karma::Engine received #{__method__}")
    end

    def enable_service(service, params = {})
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def start_service(service, params = {})
      ::Thread.abort_on_exception = true
      ::Thread.new do
        Karma.logger.debug "system #{service.command}"
        system({"PORT" => service.config_port.to_s, "KARMA_IDENTIFIER" => 'pippo@40000'}, service.command)
      end
    end

    def stop_service(service, params = {})
      ::Thread.new do
        Karma.logger.debug "system kill #{params[:pid]}"
        res = `kill #{params[:pid]}`
        Karma.logger.debug "res: #{res}"
      end
    end

    def restart_service(service, params = {})
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def export_service(service)
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def remove_service(service)
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def get_process_status_message(service, pid)
      status = show_service_by_pid(pid)
      if status.present?
        return Karma::Messages::ProcessStatusUpdateMessage.new(
          host: ::Socket.gethostname,
          project: Karma.karma_project_id,
          service: status.name,
          pid: status.pid,
          status: status.status
        )
      else
        Karma.logger.warn "Cannot find status for service #{service.full_name}@#{service.env_port} (#{pid})"
        return Karma::Messages::ProcessStatusUpdateMessage.new(
          host: ::Socket.gethostname,
          project: Karma.karma_project_id,
          service: service.full_name,
          pid: pid,
          status: Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead]
        )
      end
    end

    def running_instances_for_service(service, params = {})
      show_service(service).select{|k, v| v.status == Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running]}
    end

  end

end
