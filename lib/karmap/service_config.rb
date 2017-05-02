module Karma
  module ServiceConfig

    def self.included(base)

      base.class_attribute :config_min_running, :config_max_running, :config_memory_max, :config_cpu_quota, :config_auto_start, :config_auto_restart, :config_port, :config_num_threads, :config_log_level,
                           :config_command, :config_timeout_stop
      base.extend(ClassMethods)

      ################################################
      # service configuration
      ################################################
      base.command("bin/rails runner -e #{Karma.env} \"#{self.name}.run\"")
      base.port(5000)
      base.timeout_stop(5)
      base.min_running(1)
      base.max_running(1)
      base.auto_restart(true)
      base.auto_start(true)

      #################################################
      # thread configuration
      #################################################
      base.num_threads(1)
      base.log_level(:info)

    end

    def instance_port
      ENV['PORT'] || 8899 # port comes from service environment, 8899 is for testing
    end

    def instance_identifier
      ENV['KARMA_IDENTIFIER']
    end

    def instance_log_prefix
      instance_identifier
    end

    def name
      self.class.demodulized_name
    end

    def full_name
      self.class.full_name
    end

    module ClassMethods

      ################################################
      # service configuration
      ################################################
      def command(val)
        self.config_command = val
      end

      def port(val)
        self.config_port = val
      end

      def timeout_stop(val)
        self.config_timeout_stop = val
      end

      def min_running(val)
        self.config_min_running = val
      end

      def max_running(val)
        self.config_max_running = val
      end

      def memory_max(val)
        self.config_memory_max = val
      end

      def cpu_quota(val)
        self.config_cpu_quota = val
      end

      def auto_start(val)
        self.config_auto_start = val
      end

      def auto_restart(val)
        self.config_auto_restart = val
      end

      #################################################
      # thread configuration
      #################################################
      def num_threads(val)
        self.config_num_threads = val
      end

      def log_level(val)
        self.config_log_level = val
      end

      #################################################
      # update config methods
      #################################################
      def set_process_config(config)
        # note: port does not change
        [:min_running, :max_running, :memory_max, :cpu_quota, :auto_start, :auto_restart].each do |k|
          send(k, config[k])
        end
        get_process_config
      end

      def get_process_config
        Hash.new.tap do |h|
          [:min_running, :max_running, :memory_max, :cpu_quota, :auto_start, :auto_restart].each do |k|
            h[k] = send("config_#{k}")
          end
        end
      end

      def set_thread_config(config)
        [:num_threads, :log_level].each do |k|
          send(k, config[k])
        end
        get_thread_config
      end

      def get_thread_config
        Hash.new.tap do |h|
          [:num_threads, :log_level].each do |k|
            h[k] = send("config_#{k}")
          end
        end
      end

      #################################################
      # convenience methods
      #################################################
      def max_ports
        start_port = self.config_port
        end_port = start_port + self.config_max_running - 1
        (start_port..end_port).to_a
      end

      def min_ports
        start_port = self.config_port
        end_port = start_port + self.config_min_running - 1
        (start_port..end_port).to_a
      end

      def demodulized_name
        self.name.demodulize
      end

      def full_name
        "#{Karma.project_name}-#{Karma::Helpers::dashify(demodulized_name)}".downcase
      end

      def generate_instance_identifier(port:)
        "#{full_name}@#{port}"
      end

    end

  end
end
