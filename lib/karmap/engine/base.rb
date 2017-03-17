require 'karmap/engine'

module Karma::Engine

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

    def log_directory
      "/home/#{Karma.user}/log/#{project_name}" # TODO usare nel template
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

    def get_process_status_message(pid)
      # abstract
      # must return a Karma::Messages::ProcessStatusUpdateMessage
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

    def export_service(service, params = {})
      Karma::Engine.error('Must specify a location') unless location
      FileUtils.mkdir_p(location) rescue Karma::Engine.error("Could not create: #{location}")
      # chown(user, log_directory) TODO considerare se farlo quando la cartella dei log sara' configurabile
    end

    def remove_service(service, params = {})
      # abstract
    end
    
    def running_instances_for_service(service, params = {})
      # abstract
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
