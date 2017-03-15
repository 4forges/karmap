require 'karmap/engine'

module Karma::Engine

  class SystemRaw < Base

    def enable_service(service, params = {})
      Karma.logger.debug "systemctl enable #{service.name}"
    end

    def start_service(service, params = {})
      ::Thread.new do
        Karma.logger.debug "system #{self.service.command}"
        system self.service.command
      end
    end

    def stop_service(service, params = {})
      ::Thread.new do
        Karma.logger.debug "system kill #{params[:pid]}"
        system "kill #{params[:pid]}"
      end
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

  end

end
