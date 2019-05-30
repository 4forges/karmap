module Karma
  module ServiceConfig
    DEFAULT_PORT = 5000
    DEFAULT_TIMEOUT_STOP = 5
    DEFAULT_MIN_RUNNING = 1
    DEFAULT_MAX_RUNNING = 1
    DEFAULT_NUM_THREADS = 1
    DEFAULT_AUTO_START = true
    DEFAULT_AUTO_RESTART = true
    DEFAULT_SLEEP_TIME = 10
    DEFAULT_MEMORY_MAX = nil
    DEFAULT_CPU_QUOTA = nil
    DEFAULT_LOG_LEVEL = :info
    DEFAULT_PUSH_NOTIFICATIONS = false
    DEFAULT_NOTIFY_INTERVAL = 5

    def self.included(base)
      base.class_attribute :config_port, :config_timeout_stop, :config_min_running, :config_max_running, :config_num_threads, :config_auto_start, :config_auto_restart, :config_sleep_time, :config_memory_max, :config_cpu_quota, :config_log_level, :config_push_notifications, :config_notify_interval
      base.extend(ClassMethods)

      ################################################
      # service configuration
      ################################################
      base.port(DEFAULT_PORT)
      base.timeout_stop(DEFAULT_TIMEOUT_STOP)
      base.min_running(DEFAULT_MIN_RUNNING)
      base.max_running(DEFAULT_MAX_RUNNING)
      base.num_threads(DEFAULT_NUM_THREADS)
      base.auto_start(DEFAULT_AUTO_START)
      base.auto_restart(DEFAULT_AUTO_RESTART)
      base.sleep_time(DEFAULT_SLEEP_TIME)
      base.memory_max(DEFAULT_MEMORY_MAX)
      base.cpu_quota(DEFAULT_CPU_QUOTA)
      base.log_level(DEFAULT_LOG_LEVEL)
      base.push_notifications(DEFAULT_PUSH_NOTIFICATIONS)
      base.notify_interval(DEFAULT_NOTIFY_INTERVAL)
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
      self.class.name
    end

    def full_name
      self.class.full_name
    end

    module ClassMethods
      ################################################
      # service configuration
      ################################################
      def port(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(Integer) }
      end

      def timeout_stop(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(Integer) && val > 1 }
      end

      def min_running(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(Integer) }
      end

      def max_running(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(Integer) && val > 0 }
      end

      def memory_max(val)
        safe_assign_val(__method__, val) do |val|
          ret = false
          if val.nil? || val.is_a?(Integer) && val > 0
            ret = true
          elsif val.is_a?(String)
            segments = val.scan(/\A(\d+)(M|G)?\z/)[0]
            if segments.nil?
              ret = false
            else
              val = segments[0].to_i * (segments[1] == 'M' || segments[1].nil? ? 1 : 1.kilobyte)
              ret = true
            end
          else
            ret = false
          end
          [ret, val]
        end
      end

      def cpu_quota(val)
        safe_assign_val(__method__, val) { |val| val.nil? || (val.is_a?(Integer) && val > 0) }
      end

      def auto_start(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(TrueClass) || val.is_a?(FalseClass) }
      end

      def auto_restart(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(TrueClass) || val.is_a?(FalseClass) }
      end

      def sleep_time(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(Integer) && val > 0 }
      end

      def push_notifications(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(TrueClass) || val.is_a?(FalseClass) }
      end

      def num_threads(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(Integer) && val > 0 }
      end

      def log_level(val)
        safe_assign_val(__method__, val)
      end

      def notify_interval(val)
        safe_assign_val(__method__, val) { |val| val.is_a?(Integer) && val >= 1 }
      end

      def safe_assign_val(property_name, val, &block)
        begin
          method_name = 'config_' + property_name.to_s
          is_valid = true
          is_valid, new_val = block.call(val) if block_given?
          new_val = val if new_val.nil?
          raise Exception.new("#{val.inspect} not permitted") if !is_valid
          send(method_name + '=', new_val)
        rescue Exception => e
          Karma.logger.error { e.message }
          Karma.logger.error { "Unable to assign '#{val.inspect}' to #{property_name} -> #{send(method_name).inspect} used" }
        end
      end

      def config_cpu_accounting?
        !config_cpu_quota.nil?
      end

      def config_memory_accounting?
        !config_memory_max.nil?
      end

      #################################################
      # update config methods
      #################################################

      # sets process class config passing an hash ( can be partial )
      # returns an hash with the complete class config hash
      def set_process_config(config)
        # note: port does not change
        [:min_running, :max_running, :memory_max, :cpu_quota, :auto_start, :auto_restart, :push_notifications, :num_threads, :log_level, :notify_interval, :sleep_time].each do |k|
          send(k, config[k]) if config.key?(k)
        end
        get_process_config
      end

      # returns an hash with the complete class config hash
      def get_process_config
        Hash.new.tap do |h|
          [:min_running, :max_running, :memory_max, :cpu_quota, :auto_start, :auto_restart, :push_notifications, :num_threads, :log_level, :notify_interval, :sleep_time].each do |k|
            h[k] = send("config_#{k}")
          end
        end
      end

      #################################################
      # convenience methods
      #################################################

      # returns an array with the numbers of ports util the max
      def max_ports
        start_port = config_port
        end_port = start_port + config_max_running - 1
        (start_port..end_port).to_a
      end

      # returns an array with the numbers of ports util the min
      def min_ports
        start_port = config_port
        end_port = start_port + config_min_running - 1
        (start_port..end_port).to_a
      end

      def full_name
        "#{Karma.project_name}-#{Karma::Helpers.dashify(name)}".downcase
      end

      def generate_instance_identifier(port:)
        "#{full_name}@#{port}"
      end
    end
  end
end
