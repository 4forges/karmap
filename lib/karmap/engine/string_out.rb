require 'karmap/engine'

module Karma::Engine

  class StringOut < Base

    def enable_service(service, params = {})
      Karma.logger.debug "systemctl enable #{service.name}"
    end

    def start_service(service, params = {})
      Karma.logger.debug "systemctl start #{service.name}"
    end

    def stop_service(service, params = {})
      Karma.logger.debug "systemctl stop #{service.name}"
    end

    def restart_service(service, params = {})
      Karma.logger.debug "systemctl restart #{service.name}"
    end

    def export_service(service, params = {})
      Karma.logger.debug "export_service"
    end

    def remove_service(service, params = {})
      Karma.logger.debug "remove_service"
    end

    def get_process_status_message(pid)
      return Karma::Messages::ProcessStatusUpdateMessage.new(
        host: ::Socket.gethostname,
        project: Karma.karma_project_id,
        service: 'service',
        pid: 'pid',
        status: 'status'
      )
    end

  end

end
