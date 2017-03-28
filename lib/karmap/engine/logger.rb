require 'karmap/engine'

module Karma::Engine

  class Logger < Base

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
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def stop_service(pid, params = {})
      Karma.logger.debug("Karma::Engine received #{__method__} for #{service.full_name}")
    end

    def restart_service(pid, params = {})
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
