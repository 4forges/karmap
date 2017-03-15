require 'karmap/engine'
require 'karmap/engine/parser/systemd_parser'

module Karma::Engine

  class Systemd < Base

    def location
      "/home/#{Karma.user}/.config/systemd/user"
    end

    def show_service(service)
      SystemdParser.systemctl_show(service: service.name, user: true)
    end

    def show_all_services
      SystemdParser.systemctl_status(prefix: "#{project_name}-*@*", user: true)
    end

    def enable_service(service, params = {})
      Kernel.exec "systemctl --user enable #{service.name}"
    end

    def start_service(service, params = {})
      Kernel.exec "systemctl --user start #{service.name}"
      # START ALL systemctl --user start karmat-testservice@*
    end

    def stop_service(service, params = {})
      Kernel.exec "systemctl --user stop #{service.name}"
    end

    def restart_service(service, params = {})
      Kernel.exec "systemctl --user restart #{service.name}"
    end

    def export_service(service, params = {})

      # REFERENCE
      # https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units
      # https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files
      # https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/sect-Managing_Services_with_systemd-Unit_Files.html
      # https://wiki.archlinux.org/index.php/Systemd/User
      # https://fedoramagazine.org/systemd-template-unit-files/

      super

      remove_instance(service, params)

      service_fn = "#{project_name}-#{service.name}@.service"
      write_template 'systemd/process.service.erb', service_fn, binding

      create_directory("#{project_name}-#{service.name}.target.wants")

      instances_dir = "#{project_name}-#{service.name}.target.wants"
      instances = Dir["#{location}/#{instances_dir}/*"]

      max = service.process_config[:max_running]

      # check if there are more instances than max, and kill if needed
      if instances.size > max
        instances[max..-1].each do |file|
          instance_name = file.split('/').last
          Kernel.exec "systemctl --user stop #{instance_name}"
          clean file
        end
      end

      # check if there are less instances than max, and create if needed
      if instances.size < max
        (instances.size+1..max)
          .map{ |num| "#{project_name}-#{service.name}@#{service.port+(num-1)}.service" }
          .each do |process_name|
          create_symlink("#{instances_dir}/#{process_name}", "../#{service_fn}") rescue Errno::EEXIST
        end
      end

      write_template 'systemd/process_master.target.erb', "#{project_name}-#{service.name}.target", binding
      # process_master_names = ["#{project_name}-#{service.name}.target"]

      write_template 'systemd/master.target.erb', "#{project_name}.target", binding
    end

    def remove_instance(service, params = {})
      Dir["#{location}/#{project_name}*.target"]
        .concat(Dir["#{location}/#{project_name}*.service"])
        .each do |file|
        clean file
      end
    end

    def remove_service(service, params = {})
      Dir["#{location}/#{project_name}*.target"]
          .concat(Dir["#{location}/#{project_name}*.service"])
          .concat(Dir["#{location}/#{project_name}*.target.wants/#{project_name}*.service"])
          .each do |file|
        clean file
      end

      Dir["#{location}/#{project_name}*.target.wants"].each do |file|
        clean_dir file
      end
    end

  end

end
