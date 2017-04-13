require 'karmap/engine'

module Karma::Engine

  ServiceStatus = Struct.new(:name, :port, :status, :pid, :threads, :memory, :cpu)

  class Base
    include Karma::Helpers

    attr_accessor :service

    def location
      nil # override (engine dependant)
    end

    def project_name
      Karma.project_name
    end

    def work_directory
      Dir.pwd
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

    def show_service_log(service)
      # abstract
    end

    def enable_service(service, params = {})
      # abstract
    end

    def start_service(service, params = {})
      # abstract
    end

    def stop_service(pid, params = {})
      # abstract
    end

    def restart_service(pid, params = {})
      # abstract
    end

    def export_service(service)
      FileUtils.mkdir_p(location) if location
    end

    def remove_service(service)
      # abstract
    end

    def get_process_status_message(service, pid, params = {})
      status = show_service_by_pid(pid)
      if status.present?
        attrs = {
          host: ::Socket.gethostname,
          project: Karma.karma_project_id,
          service: service.name,
          pid: status.values[0].pid,
          status: status.values[0].status,
          active_threads: params[:active_threads],
          execution_time: params[:execution_time],
          performance_execution_time: params[:performance_execution_time],
          performance:  params[:performance]
        }
        attrs[:status] = params[:status] if params[:status].present?
      else
        Karma.logger.warn{ "#{__method__}: cannot find status for service #{service.name} (#{pid})" }
        attrs = {
          host: ::Socket.gethostname,
          project: Karma.karma_project_id,
          service: service.name,
          pid: pid,
          status: Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:dead]
        }
      end
      msg = Karma::Messages::ProcessStatusUpdateMessage.new(attrs)
      return msg
    end

    def running_instances_for_service(service)
      show_service(service).select{|k, v| v.status == Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running]}
    end

    def to_be_stopped_instances(service)
      running_instances = running_instances_for_service(service) #keys: [:pid, :full_name, :port]
      running_ports = running_instances.values.map{ |i| i.port.to_i }
      Karma.logger.debug{ "#{__method__}: #{running_ports.size} running instances found for #{service.name}" }

      to_be_stopped_ports = running_ports - service.class.max_ports
      Karma.logger.debug{ "#{__method__}: #{to_be_stopped_ports.size} running instances to be stopped" }
      running_instances.values.select do |i|
        to_be_stopped_ports.include?(i.port)
      end
    end

    def to_be_started_ports(service)
      running_instances = running_instances_for_service(service) #keys: [:pid, :full_name, :port]
      running_ports = running_instances.values.map{ |i| i.port.to_i }
      Karma.logger.debug{ "#{__method__}: #{running_ports.size} running instances found for #{service.name}" }

      to_be_started_ports = service.class.min_ports - running_ports
      Karma.logger.debug{ "#{__method__}: #{to_be_started_ports.size} running instances to be started" }
      to_be_started_ports
    end

    def free_ports(service)
      running_instances = running_instances_for_service(service) #keys: [:pid, :full_name, :port]
      running_ports = running_instances.values.map{ |i| i.port.to_i }
      Karma.logger.debug{ "#{__method__}: #{running_ports.size} running instances found for #{service.name}" }

      free_ports = service.class.max_ports - running_ports
      Karma.logger.debug{ "#{__method__}: #{free_ports.size} free ports" }
      free_ports
    end

    private ######################################################################

    def clean(filename)
      return unless File.exists?(filename)
      Karma.logger.debug{ "cleaning up: #{filename}" }
      FileUtils.rm(filename)
    end

    def clean_dir(dirname)
      return unless File.exists?(dirname)
      Karma.logger.debug{ "cleaning up directory: #{dirname}" }
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
      Karma.logger.debug{ "setting #{file} to mode #{mode}" }
      FileUtils.chmod mode, File.join(location, file)
    end

    def chown(user, dir)
      FileUtils.chown user, nil, dir
    rescue
      Karma::Engine.error("Could not chown #{dir} to #{user}") unless File.writable?(dir) || !File.exists?(dir)
    end

    def create_directory(dir)
      Karma.logger.debug{ "creating: #{dir}" }
      FileUtils.mkdir_p(File.join(location, dir))
    end

    def create_symlink(link, target)
      Karma.logger.debug{ "symlinking: #{link} -> #{target}" }
      FileUtils.symlink(target, File.join(location, link))
    end

    def write_file(filename, contents)
      Karma.logger.debug{ "writing: #{filename}" }
      filename = File.join(location, filename) unless Pathname.new(filename).absolute?
      File.open(filename, "w") do |file|
        file.puts contents
      end
    end

  end

end
