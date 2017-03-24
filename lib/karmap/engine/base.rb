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

    def get_process_status_message(pid)
      begin
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
          return nil
        end

      rescue ::Exception => e
        Karma.logger.error "Error during get_process_status_message for pid #{pid}"
        Karma.logger.error e.message
        Karma.logger.error e.backtrace.join("\n")
        return nil
      end
      
    end

    def running_instances_for_service(service, params = {})
      show_service(service).select{|k, v| v.status == Karma::Messages::ProcessStatusUpdateMessage::STATUSES[:running]}
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
