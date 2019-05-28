module Karma::Thread
  class ManagedThread
    attr_reader :thread

    def self.internal_key_prefix
      'Karma::Thread::ManagedThread_'
    end

    def initialize(blocks = {}, options = {})
      @thread = nil
      @running_sleep_time = options[:running_sleep_time] || 1
      blocks[:starting] ||= proc { Karma.logger.debug { "#{$$}::#{Thread.current} starting" } }
      blocks[:finishing] ||= proc { Karma.logger.debug { "#{$$}::#{Thread.current} finishing" } }
      blocks[:running] ||= proc { Karma.logger.debug { "#{$$}::#{Thread.current} running" } }
      blocks[:performance] ||= proc { Karma.logger.debug { "#{$$}::#{Thread.current} performance" } }

      Thread.abort_on_exception = true # only for debug
      @thread = ::Thread.new do
        begin
          Thread.current[:status] = :initing
          Thread.current[:initing_at] = Time.now
          Thread.current[:last_running_at] = Thread.current[:initing_at]
          Thread.current[:parent_class] = self
          Thread.current[:internal_key] = "#{Karma::Thread::ManagedThread.internal_key_prefix}#{$$}"
          Thread.current[:is_managed_thread] = true
          Thread.current[:status] = :inited
          Thread.current[:thread_index] = options[:thread_index]
          Karma.logger.debug { "#{$$}::#{Thread.current} initialized #{Thread.current[:status]}" }
          sleep 0.1 until Thread.current[:status] == :running
          Karma.logger.debug { "#{$$}::#{Thread.current} started #{Thread.current[:status]}" }
          outer_block(blocks)
        rescue Exception => e
          Karma.logger.error { "#{$$}::#{Thread.current} #{e.message}" }
          raise e
        end
      end
      # @thread[:custom_inspect_block] ||= Proc.new { "#{$$}::#{@thread[:thread_index]} #{Time.now} custom_inspect" }
    end

    def to_s
      "#{@thread.inspect} index:#{@thread[:thread_index]} status:#{@thread[:status]}, initing_at:#{@thread[:initing_at]}, last_running_at:#{@thread[:last_running_at]} (#{Time.now - @thread[:last_running_at]} secs ago)"
    end

    def get_log_level
      return 0 if @thread.nil?

      @thread[:logger].level || 0
    end

    def set_log_level(level)
      Karma.logger.level = level
      @thread[:logger].level = level if @thread[:logger].present?
    end

    def thread_index
      @thread[:thread_index]
    end

    def start
      @thread[:status] = :running
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

    def kill_inner_thread
      @thread.kill
    end

    def execution_time
      @thread[:execution_time]
    end

    def performance_execution_time
      @thread[:performance_execution_time]
    end

    def performance
      @thread[:performance]
    end

    def outer_block(blocks = {})
      begin
        blocks[:starting].call
        while !stopping? && !failed?
          begin
            case @thread[:status]
              when :running
                @thread[:start_time] = Time.now
                blocks[:running].call
                @thread[:end_time] = Time.now
                @thread[:execution_time] = @thread[:end_time] - @thread[:start_time]

                @thread[:performance_start_time] = Time.now
                begin
                  blocks[:performance].call
                rescue ::Exception => e
                  Karma.logger.error { "Error during performance block: #{e.message}" }
                  @thread[:performance] = 0
                end
                @thread[:performance_end_time] = Time.now
                @thread[:performance_execution_time] = @thread[:performance_end_time] - @thread[:performance_start_time]

                Karma.logger.debug { "Execution time: #{@thread[:execution_time]}" }
                Karma.logger.debug { "Performance: #{@thread[:performance]}" }
                Karma.logger.debug { "Performance execution time: #{@thread[:performance_execution_time]}" }
                Thread.current[:last_running_at] = Time.now

              else
                Karma.logger.debug { "Thread status: #{@thread[:status]}" }
              end
            sleep @running_sleep_time
          rescue ::Exception => e
            @thread[:status] = :error
            Karma.logger.error { e }
          end
        end
        if stopping?
          blocks[:finishing].call
          @thread[:status] = :stopped
          Thread.current[:stopped_at] = Time.now
        end
      rescue ::Exception => e
        @thread[:status] = :error
        Karma.logger.error { e }
      end
    end

    def running_default_block
      Karma.logger.debug { "#{$$}::#{Thread.current} running - #{Time.now}" }
    end
  end
end
