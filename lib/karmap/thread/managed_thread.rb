module Karma::Thread

  class ManagedThread

    def self.internal_key_prefix
      "Karma::Thread::ManagedThread_"
    end

    def thread_logger
      if Thread.current[:logger].nil?
        Thread.current[:logger] = Logger.new("#{@log_prefix}-#{Thread.current[:thread_index]}.log", shift_age = Karma::Service::LOGGER_SHIFT_AGE, shift_size = Karma::Service::LOGGER_SHIFT_SIZE)
        Thread.current[:logger].level = Logger::DEBUG #Logger::DEBUG #Logger::WARN
      end
      Thread.current[:logger]
    end

    def initialize(blocks = {}, options = {})
      @thread = nil
      @log_prefix = options[:log_prefix]
      @running_sleep_time = options[:running_sleep_time]||1
      blocks[:starting] ||= Proc.new { thread_logger.debug "#{$$}::#{Thread.current.to_s} Starting" }
      blocks[:finishing] ||= Proc.new { thread_logger.debug "#{$$}::#{Thread.current.to_s} Finishing" }
      blocks[:running] ||= Proc.new { thread_logger.debug "#{$$}::#{Thread.current.to_s} Running" }
      @thread = ::Thread.new do
        Thread.current[:status] = :initing
        Thread.current[:initing_at] = Time.now
        Thread.current[:last_running_at] = Thread.current[:initing_at]
        Thread.current[:parent_class] = self
        Thread.current[:internal_key] = "#{Karma::Thread::ManagedThread.internal_key_prefix}#{$$}"
        Thread.current[:is_managed_thread] = true
        Thread.current[:status] = :inited
        Thread.current[:thread_index] = options[:thread_index]
        thread_logger.debug "#{$$}::#{Thread.current.to_s} inited"
        Thread.stop
        outer_block(blocks)
      end
      @thread.abort_on_exception = true #only for debug
    end

    def to_s
      "#{@thread.inspect} index:#{@thread[:thread_index]} status:#{@thread[:status]}, initing_at:#{@thread[:initing_at]}, last_running_at:#{@thread[:last_running_at]}"
    end

    def set_log_level(level)
      thread_logger.level = level
    end

    def start
      @thread[:status] = :running
      @thread.run
    end

    def stop
      @thread[:status] = :stopping
    end

    def running?
      @thread[:status] == :running
    end

    def initing?
      @thread[:status] == :initing
    end

    def inited?
      @thread[:status] == :inited
    end

    def stopping?
      @thread[:status] == :stopping
    end

    def stopped?
      @thread[:status] == :stopped
    end

    def status
      @thread[:status]
    end

    def freezed?(threshold)
      ret = (initing? && Time.now - (@thread[:last_running_at]||0) > 10) || (Time.now - (@thread[:last_running_at]||0) > threshold)
      if ret
        @thread[:status] = :freezed
        @thread[:freezed_at] = Time.now
      end
      ret
    end

    def outer_block(blocks = {})
      # logger.debug "#{$$}::#{Thread.current.to_s} pre starting"
      blocks[:starting].call
      # logger.debug "#{$$}::#{Thread.current.to_s} post starting"
      while @thread[:status] != :stopping
        begin
          # logger.debug "#{$$}::#{Thread.current.to_s} loop start"
          case @thread[:status]
          when :running
            # thread_logger.debug "#{$$}::#{Thread.current.to_s} pre running"
            blocks[:running].call
            # thread_logger.debug "#{$$}::#{Thread.current.to_s} post running"
          when :stopping
          when :error
            # thread_logger.debug "#{$$}::#{Thread.current.to_s} thread in error. sleep 10 sec"
            sleep 10
          end
          sleep @running_sleep_time
          # thread_logger.debug "#{$$}::#{Thread.current.to_s} loop end"
        rescue Exception => e
          # full_log_exception(logger: @@logger, message: "Thread #{$$} in error", e: e, send_notify_now: true)
          @thread[:status] == :error
        end
      end
      # thread_logger.debug "#{$$}::#{Thread.current.to_s} pre finishing"
      blocks[:finishing].call
      # thread_logger.debug "#{$$}::#{Thread.current.to_s} post finishing"
      @thread[:status] = :stopped
      Thread.current[:stopped_at] = Time.now
    end

    def running_default_block
      thread_logger.debug "#{$$}::#{Thread.current.to_s} #{Time.now}"
    end
  end

end
