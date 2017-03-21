module Karma
  module ServiceConfig

    def self.included(base)
      base.cattr_accessor :config_min_running, :config_max_running, :config_memory_max, :config_cpu_quota, :config_auto_start, :config_auto_restart, :config_port, :config_num_threads, :config_log_level
      base.extend(ClassMethods)
      ################################################
      # process configuration
      ################################################
      base.min_running(1)
      base.max_running(1)
      base.port(5000)
      base.auto_restart(true)

      #################################################
      # thread configuration
      #################################################
      base.num_threads(1)
      base.log_level(:info)
    end

    module ClassMethods

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

      def port(val)
        self.config_port = val
      end

      def num_threads(val)
        self.config_num_threads = val
      end

      def log_level(val)
        self.config_log_level = val
      end

      def update_process_config(config)
        [:min_running, :max_running, :memory_max, :cpu_quota, :auto_start, :auto_restart, :port].each do |k|
          self.send(k, config[k])
        end
      end

      def update_thread_config(config)
        [:num_threads, :log_level].each do |k|
          self.send(k, config[k])
        end
      end
    end


  end
end
