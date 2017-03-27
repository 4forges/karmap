require 'karmap/engine'
require 'karmap/engine/parser/systemd_parser'

module Karma::Engine

  class Systemd < Base

    def location
      "/home/#{Karma.user}/.config/systemd/user"
    end

    def reload
      `systemctl --user daemon-reload`
      # `systemctl --user reset-failed`
    end

    def show_service(service)
      service_status(service: "#{service.full_name}@*")
    end

    def show_service_by_pid(pid)
      service_status(service: pid)
    end

    def show_all_services
      service_status(service: "#{project_name}-*@*")
    end

    def enable_service(service)
      `systemctl --user enable #{service.full_name}`
    end

    def start_service(service)
      # get first stopped instance name and start it
      Karma.logger.debug("starting #{service.full_name}")
      status = show_service(service)
      (1..service.class.config_max_running).each do |i|
        instance_name = "#{service.full_name}@#{service.class.config_port+(i-1)}.service"
        if status[instance_name].nil?
          Karma.logger.info("starting instance #{instance_name}!")
          `systemctl --user start #{instance_name}`
          return instance_name
        end
      end
      return false
    end

    def stop_service(pid)
      # get instance by pid and stop it
      status = show_service_by_pid(pid)
      instance_name = status.keys[0]
      Karma.logger.info("stopping instance #{instance_name}!")
      `systemctl --user stop #{instance_name}`
    end

    def restart_service(pid)
      # get instance by pid and restart it
      status = show_service_by_pid(pid)
      instance_name = status.keys[0]
      Karma.logger.info("stopping instance #{instance_name}!")
      `systemctl --user restart #{instance_name}`
    end

    def export_service(service)

      # REFERENCE
      # https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units
      # https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files
      # https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/sect-Managing_Services_with_systemd-Unit_Files.html
      # https://wiki.archlinux.org/index.php/Systemd/User
      # https://fedoramagazine.org/systemd-template-unit-files/
      # https://www.freedesktop.org/software/systemd/man/systemctl.html
      # https://www.freedesktop.org/software/systemd/man/systemd.unit.html#Specifiers

      Karma.logger.info("started systemd export for service #{service.name}")

      super

      service_fn = "#{service.full_name}@.service"
      clean "#{location}/#{service_fn}"
      write_template 'systemd/process.service.erb', service_fn, binding

      instances_dir = "#{service.full_name}.target.wants"
      create_directory(instances_dir)

      instances = Dir["#{location}/#{instances_dir}/*"].sort
      max = service.class.config_max_running

      # check if there are more instances than max, and delete/stop if needed
      if instances.size > max
        instances[max..-1].each do |file|
          instance_name = file.split('/').last
          `systemctl --user stop #{instance_name}`
          clean file
        end

      # check if there are less instances than max, and create if needed
      elsif instances.size < max
        (instances.size+1..max)
          .map{ |num| "#{service.full_name}@#{service.class.config_port+(num-1)}.service" }
          .each do |instance_name|
          create_symlink("#{instances_dir}/#{instance_name}", "../#{service_fn}") rescue Errno::EEXIST
        end

      end

      target_fn = "#{service.full_name}.target"
      clean "#{location}/#{target_fn}"
      write_template 'systemd/process_master.target.erb', target_fn, binding
      # process_master_names = ["#{project_name}-#{service.name}.target"]

      write_template 'systemd/master.target.erb', "#{project_name}.target", binding

      reload

      Karma.logger.info("end systemd export for service #{service.name}")
    end

    def remove_service(service)
      Dir["#{location}/#{service.full_name}*.service"]
          .concat(Dir["#{location}/#{service.full_name}.target"])
          .concat(Dir["#{location}/#{service.full_name}*.target.wants/*"])
          .each do |file|
        clean file
      end

      Dir["#{location}/#{service.full_name}*.target.wants"].each do |file|
        clean_dir file
      end
    end

    private ####################

    def service_status(service:)
      status = SystemdParser.systemctl_status(service: service, user: true)
      ret = {}
      status.each do |k,v|
        # :name, :port, :status, :pid, :threads, :memory, :cpu
        data = /(.*)@(.*)\.(.*)/.match(k)
        ret[k] = Karma::Engine::ServiceStatus.new(
          data[1],
          data[2].to_i,
          to_karma_status(v['Active']),
          v['Main PID'].to_i,
          v['Tasks'].to_i,
          v['Memory'],
          v['CPU'],
        )
      end
      return ret
    end

    def to_karma_status(process_status)
      case process_status
        when 'active', 'deactivating'
          Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running]
        when 'inactive', 'activating'
          Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:stopped]
        else
          Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead]
      end
    end

  end

end
