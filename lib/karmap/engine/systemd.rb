require 'karmap/engine'
require 'karmap/engine/parser/systemd_parser'

module Karma::Engine

  class Systemd < Base

    def location
      "#{Karma.home_path}/.config/systemd/user"
    end
    
    def instance_full_name(service, port)
      "#{service.full_name}@#{port}.service"
    end

    def show_service(service)
      # note: does not show dead units
      service_status(service: "#{service.full_name}@*")
    end

    def show_service_by_pid(pid)
      #service_status(service: pid)
      show_all_services.select{ |k, status| status.pid == pid}
    end

    def show_all_services
      service_status(service: "#{project_name}-*@*")
    end

    def show_service_log(service)
      service_log(service: "#{service.full_name}@*")
    end

    def enable_service(service)
      `systemctl --user enable #{service.full_name}`
    end

    def show_enabled_services
      `systemctl --user list-unit-files | grep enabled`.split("\n").map{|s| s.split('@')[0]}
    end
    
    def wait_started(service, key, timeout)
      Karma.logger.debug{ "#{__method__}: Enter" }
      wait_test = false
      ret = false
      while wait_test == false
        service_status = show_service(service)
        wait_test = service_status[key].present? && service_status[key].status == 'running'
        if !wait_test
          Karma.logger.debug{ "#{__method__}: false -> #{service_status}" }
          sleep 1
        else
          Karma.logger.debug{ "#{__method__}: true -> #{service_status}" }
          ret = true
        end
      end
      Karma.logger.debug{ "#{__method__}: Exit" }
      ret
    end

    def wait_stopped(pid, key, timeout)
      Karma.logger.debug{ "#{__method__}: Enter" }
      wait_test = false
      ret = false
      while wait_test == false
        service_status = show_service_by_pid(pid)
        wait_test = service_status.empty?
        if !wait_test
          Karma.logger.debug{ "#{__method__}: false -> #{service_status}" }
          sleep 1
        else
          Karma.logger.debug{ "#{__method__}: true -> #{service_status}" }
          ret = true
        end
      end
      Karma.logger.debug{ "#{__method__}: Exit" }
      ret
    end

    # starts the first available not running instance
    def start_service(service, params = {})
      params[:check] = true if params[:check].nil?
      Karma.logger.debug{ "#{__method__}: starting #{service.full_name} with params: #{params.inspect}" }
      `systemctl --user reset-failed`
      running_instances = show_service(service).keys
      should_running_instances = (1..service.config_max_running).map { |p| instance_full_name(service, service.config_port + (p - 1)) }
      to_be_started_instance = (should_running_instances - running_instances).first
      if to_be_started_instance
        Karma.logger.info{ "#{__method__}: starting instance #{to_be_started_instance}" }
        `systemctl --user start #{to_be_started_instance}`
        if params[:check]
          ret = wait_started(service, to_be_started_instance, 5) ? to_be_started_instance : false
        else
          ret = to_be_started_instance
        end
      else
        ret = false
      end
      return ret
    end

    def stop_service(pid, params = {})
      params[:check] = true if params[:check].nil?
      Karma.logger.debug{ "#{__method__}: stopping #{pid}" }
      ret = false
      begin
        # get instance by pid and stop it
        `systemctl --user reset-failed`
        status = show_service_by_pid(pid)
        to_be_stopped_instance = status.keys[0]
        Karma.logger.info{ "#{__method__}: stopping instance #{to_be_stopped_instance} - #{status}" }
        `systemctl --user stop #{to_be_stopped_instance}`
        if params[:check]
          ret = wait_stopped(pid, to_be_stopped_instance, 5) ? to_be_stopped_instance : false
        else
          ret = to_be_stopped_instance
        end
      rescue Exception => e
        Karma.logger.error{ "#{__method__}: ERRORE!!!! #{e.message}" }
      end
      ret
    end

    def restart_service(pid, params = {})
      # get instance by pid and restart it
      Karma.logger.debug{ "#{__method__}: restarting #{pid}" }
      `systemctl --user reset-failed`
      status = show_service_by_pid(pid)
      instance_name = status.keys[0]
      Karma.logger.info{ "#{__method__}: restarting instance #{instance_name}" }
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

      Karma.logger.info{ "#{__method__}: started systemd export for service #{service.name}" }

      super

      service_fn = "#{service.full_name}@.service"
      clean "#{location}/#{service_fn}"
      write_template 'systemd/process.service.erb', service_fn, binding

      instances_dir = "#{service.full_name}.target.wants"
      create_directory(instances_dir)

      instances = Dir["#{location}/#{instances_dir}/*"].sort
      max = service.config_max_running

      # check if there are more instances than max, and delete/stop if needed
      if instances.size > max
        instances[max..-1].each do |file|
          instance_name = file.split('/').last
          `systemctl --user stop #{instance_name}`
          clean file
        end
        `systemctl --user reset-failed`

      # check if there are less instances than max, and create if needed
      elsif instances.size < max
        (instances.size+1..max)
          .map{ |num| instance_full_name(service, service.config_port + (num - 1)) }
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

      if service == Karma::Watchdog
        instance_name =  instance_full_name(Karma::Watchdog, Karma.watchdog_port)
        `systemctl enable --user #{instance_name}`
      end

      Karma.logger.info { "#{__method__}: end systemd export for service #{service.name}" }
    end

    def remove_service(service)
      Dir["#{location}/#{service.full_name}*.service"]
          .concat(Dir["#{location}/#{service.full_name}.config"])
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

    def reload
      `systemctl --user daemon-reload`
    end

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
          v['Tasks'].to_i, # TODO should return actual thread count
          v['Memory'],
          v['CPU'],
        )
      end
      return ret
    end

    def service_log(service:)
      return SystemdParser.journalctl(service: service, user: true, lines: 100)
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
