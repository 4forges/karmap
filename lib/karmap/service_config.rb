module Karma
  module ServiceConfig

    def self.included(base)
      base.extend(ClassMethods)
      base.class_attribute :min_running, :max_running, :memory_max, :cpu_quota, :auto_start, :auto_restart, :port, :num_threads, :log_level
    end

    module ClassMethods

      def base_min_running(val)
        self.min_running = val
      end

      def base_max_running(val)
        self.max_running = val
      end

      def base_memory_max(val)
        self.memory_max = val
      end

      def base_cpu_quota(val)
        self.cpu_quota = val
      end

      def base_auto_start(val)
        self.auto_start = val
      end

      def base_auto_restart(val)
        self.auto_restart = val
      end

      def base_port(val)
        self.port = val
      end

      def base_num_threads(val)
        self.num_threads = val
      end
    end
    def base_log_level(val)
      self.log_level = val
    end
    
  end
end