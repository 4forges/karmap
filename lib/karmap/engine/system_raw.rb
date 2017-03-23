require 'karmap/engine'

module Karma::Engine

  class SystemRaw < Base

    def reload
      Karma.logger.debug("Karma::Engine received #{__method__}")
    end

    def show_service(service)
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def show_service_by_pid(pid)
      Karma.logger.debug("Karma::Engine received #{__method__} for #{pid}")
    end

    def show_all_services
      Karma.logger.debug("Karma::Engine received #{__method__}")
    end

    def enable_service(service, params = {})
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
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
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def export_service(service)
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def remove_service(service)
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

  end

end
