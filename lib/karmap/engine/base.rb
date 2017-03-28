require 'karmap/engine'

module Karma::Engine

  ServiceStatus = Struct.new(:name, :port, :status, :pid, :threads, :memory, :cpu)

  class Base

    attr_accessor :service

    def location
      nil # override (engine dependant)
    end

    def project_name
      Karma.project_name
    end

    def user
      Karma.user
    end

    def work_directory
      Dir.pwd
    end

    def reload
      # abstract
    end

    def show_service(service)
      # abstract
    end

    def show_service_by_pid(pid)
      # abstract
    end

    def show_all_services
      # abstract
    end

    def enable_service(service, params = {})
      # abstract
    end

    def start_service(service, params = {})
      # abstract
    end

    def stop_service(service, params = {})
      # abstract
    end

    def restart_service(service, params = {})
      # abstract
    end

    def export_service(service)
      Karma::Engine.error('Must specify a location') unless location
      FileUtils.mkdir_p(location) rescue Karma::Engine.error("Could not create: #{location}")
    end

    def remove_service(service)
      # abstract
    end

    def get_process_status_message(service, pid)
      status = show_service_by_pid(pid)
      if status.present?
        return Karma::Messages::ProcessStatusUpdateMessage.new(
          host: ::Socket.gethostname,
          project: Karma.karma_project_id,
          service: status.values[0].name,
          pid: status.values[0].pid,
          status: status.values[0].status
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

    def to_be_stopped_instanced(service)
      running_instances = running_instances_for_service(service) #keys: [:pid, :full_name, :port]
      num_running = running_instances.size
      all_ports_max = ( service.class.config_port..service.class.config_port + service.class.config_max_running - 1 ).to_a
      all_ports_min = ( service.class.config_port..service.class.config_port + service.class.config_min_running - 1 ).to_a
      running_ports = running_instances.values.map{ |i| i.port }
      logger.debug("Running instances found: #{num_running}")

      # stop instances
      to_be_stopped_ports = running_ports - all_ports_max
    end

    private ######################################################################

    def clean(filename)
      return unless File.exists?(filename)
      Karma.logger.info "cleaning up: #{filename}"
      FileUtils.rm(filename)
    end

    def clean_dir(dirname)
      return unless File.exists?(dirname)
      Karma.logger.info "cleaning up directory: #{dirname}"
      FileUtils.rm_r(dirname)
    end

    def shell_quote(value)
      Shellwords.escape(value)
    end

    def export_template(name)
      matchers = []
      matchers << File.expand_path(Karma.template_folder) if Karma.template_folder
      matchers << File.expand_path("~/.karma/templates/#{name}")
      matchers << File.expand_path("../../../../data/export/#{name}", __FILE__)
      File.read(matchers.detect { |m| File.exists?(m) })
    end

    def write_template(name, target, binding)
      compiled = ERB.new(export_template(name), nil, '-').result(binding)
      write_file target, compiled
    end

    def chmod(mode, file)
      Karma.logger.info "setting #{file} to mode #{mode}"
      FileUtils.chmod mode, File.join(location, file)
    end

    def chown(user, dir)
      FileUtils.chown user, nil, dir
    rescue
      Karma::Engine.error("Could not chown #{dir} to #{user}") unless File.writable?(dir) || ! File.exists?(dir)
    end

    def create_directory(dir)
      Karma.logger.info "creating: #{dir}"
      FileUtils.mkdir_p(File.join(location, dir))
    end

    def create_symlink(link, target)
      Karma.logger.info "symlinking: #{link} -> #{target}"
      FileUtils.symlink(target, File.join(location, link))
    end

    def write_file(filename, contents)
      Karma.logger.info "writing: #{filename}"
      filename = File.join(location, filename) unless Pathname.new(filename).absolute?
      File.open(filename, "w") do |file|
        file.puts contents
      end
    end

  end

end
