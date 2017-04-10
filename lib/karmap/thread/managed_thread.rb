module Karma::Thread

  class ManagedThread

    def self.internal_key_prefix
      'Karma::Thread::ManagedThread_'
    end

    def initialize(blocks = {}, options = {})
      @thread = nil
      @running_sleep_time = options[:running_sleep_time]||1
      blocks[:starting] ||= Proc.new { Karma.logger.debug "#{$$}::#{Thread.current.to_s} Starting" }
      blocks[:finishing] ||= Proc.new { Karma.logger.debug "#{$$}::#{Thread.current.to_s} Finishing" }
      blocks[:running] ||= Proc.new { Karma.logger.debug "#{$$}::#{Thread.current.to_s} Running" }
      @thread = ::Thread.new do
        Thread.current[:status] = :initing
        Thread.current[:initing_at] = Time.now
        Thread.current[:last_running_at] = Thread.current[:initing_at]
        Thread.current[:parent_class] = self
        Thread.current[:internal_key] = "#{Karma::Thread::ManagedThread.internal_key_prefix}#{$$}"
        Thread.current[:is_managed_thread] = true
        Thread.current[:status] = :inited
        Thread.current[:thread_index] = options[:thread_index]
        Karma.logger.info "#{$$}::#{Thread.current.to_s} inited"
        Thread.stop
        outer_block(blocks)
      end
      @thread.abort_on_exception = true #only for debug
    end

    def to_s
      "#{@thread.inspect} index:#{@thread[:thread_index]} status:#{@thread[:status]}, initing_at:#{@thread[:initing_at]}, last_running_at:#{@thread[:last_running_at]}"
    end

    def set_log_level(level)
      Karma.logger.level = level
    end

    def thread_index
      @thread[:thread_index]
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

    def failed?
      @thread[:status] == :error
    end

    def status
      @thread[:status]
    end

    def frozen?(threshold)
      ret = (initing? && Time.now - (@thread[:last_running_at]||0) > 10) || (Time.now - (@thread[:last_running_at]||0) > threshold)
      if ret
        @thread[:status] = :frozen
        @thread[:frozen_at] = Time.now
      end
      ret
    end

    def outer_block(blocks = {})
      begin
        blocks[:starting].call
        while !stopping? && !failed?
          begin
            case @thread[:status]
              when :running
                blocks[:running].call
              else
                Karma.debug.debug { "Thread status: #{@thread[:status]}" }
              end
            sleep @running_sleep_time
          rescue ::Exception => e
            @thread[:status] = :error
            Karma.logger.error e
          end
        end
        if stopping?
          blocks[:finishing].call
          @thread[:status] = :stopped
          Thread.current[:stopped_at] = Time.now
        end
      rescue ::Exception => e
        @thread[:status] = :error
        Karma.logger.error e
      end
    end

    def running_default_block
      Karma.logger.debug("#{$$}::#{Thread.current.to_s} #{Time.now}")
    end

  end

end
