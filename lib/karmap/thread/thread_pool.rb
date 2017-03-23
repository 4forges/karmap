module Karma::Thread

  class ThreadPool

    FREEZED_THREADS_TIMEOUT = 1.hours

    attr_accessor :thread
    cattr_accessor :list, :thread_index

    def initialize(task_block, options = {})
      @task_block = task_block
      @list = []
      @thread_index = 0
      @log_prefix = options[:log_prefix]
    end

    def manage(config = nil)
      @default_config ||= config
      @current_config = config || @default_config

      max_workers = @current_config[:num_threads]
      log_level = @current_config[:log_level]
      # Karma.logger.debug "manage workers max_workers: #{max_workers}"
      # Karma.logger.debug "kill freezed from more than older than #{FREEZED_THREADS_TIMEOUT.to_i} sec"
      num_killed = kill_freezed(FREEZED_THREADS_TIMEOUT.to_i)
      # Karma.logger.debug "num_killed: #{num_killed}"
      # Karma.logger.debug '#prune freezed and stopped'
      num_pruned = prune_list
      # Karma.logger.debug "num_pruned: #{num_pruned}"
      while (running.size + initing.size) < max_workers
        # Karma.logger.debug 'inited new thread'
        add({running: @task_block}, { running_sleep_time: @current_config[:sleep_time], log_prefix: @log_prefix })
      end
      while (running.size + initing.size) > max_workers
        stop
      end

      # Karma.logger.info "#allocated threads:"
      # @list.each{ |thread_string| Karma.logger.info(thread_string) }

      set_log_level(log_level)
    end

    # private

    def running
      @list.select{|thread| thread.running?}
    end

    def initing
      @list.select{|thread| thread.initing?}
    end

    def stopping
      @list.select{|thread| thread.stopping?}
    end

    def freezed(threshold)
      @list.select{|thread| thread.freezed?(threshold)}
    end

    def kill_freezed(threshold)
      ret = 0
      freezed(threshold).map{|t| ret+=1; t.thread.kill}
      ret
    end

    def prune_list
      ret = 0
      @list.reject! do |managed_thread|
        is_freezed = managed_thread.freezed?(10.minutes)
        is_stopped = managed_thread.stopped?
        ret += 1 if is_stopped || is_freezed
        is_stopped || is_freezed
      end
      ret
    end

    def set_log_level(log_level)
      running.map{|managed_thread| managed_thread.set_log_level(log_level)}
    end

    def add(blocks = {}, options = {})
      @thread_index ||= 0
      if options[:thread_index].nil?
        @thread_index += 1
        options[:thread_index] = @thread_index
      end
      new_thread = Karma::Thread::ManagedThread.new(blocks, options)
      @list << new_thread
      while !new_thread.inited?
        sleep 0.1
      end
      new_thread.start
    end

    def stop
      running.last.stop unless running.last.nil?
    end

    def stop_all
      running.each do |managed_thread|
        managed_thread.stop
      end
      prune_list
      running.count
    end

    def reload_list
      @list = Thread.list.select{|t| (t[:internal_key]||"").starts_with?(Karma::Thread::ManagedThread.internal_key_prefix)}.map{|t| t[:parent_class]}
    end

  end

end
