module Karma::Thread

  class ThreadPool

    FROZEN_THREADS_TIMEOUT = 1.hours.to_i

    attr_accessor :thread
    cattr_accessor :list, :thread_index

    def initialize(task_block, options = {})
      @task_block = task_block
      @list = []
      @thread_index = 0
    end

    def manage(config = nil)
      @default_config ||= config
      @current_config = config || @default_config

      max_workers = @current_config[:num_threads]
      log_level = @current_config[:log_level]
      Karma.logger.debug { 'Killing frozen threads...' }
      num_killed = kill_frozen(FROZEN_THREADS_TIMEOUT)
      Karma.logger.debug { "#{num_killed} killed" }
      Karma.logger.debug { 'Pruning stopped threads...' }
      num_pruned = prune_list
      Karma.logger.debug { "#{num_pruned} pruned" }
      
      Karma.logger.debug { "Active size: #{active.size} "}
      while (active.size) < max_workers
        Karma.logger.debug { "Add new thread"}
        add({running: @task_block}, { running_sleep_time: @current_config[:sleep_time] })
      end

      while (active.size) > max_workers
        Karma.logger.debug { "Stop thread"}
        stop
      end

      # Karma.logger.debug { "Set log level to #{log_level}"}
      # set_log_level(log_level)
    end

    def all
      Thread.list.select{|t| (t[:internal_key]||'').starts_with?(Karma::Thread::ManagedThread.internal_key_prefix)}
    end

    def running
      @list.select{|thread| thread.running?}
    end

    def initing
      @list.select{|thread| thread.initing?}
    end
    
    def active
      @list.select{|managed_thread| managed_thread.initing? || managed_thread.running? }
    end

    def stopping
      @list.select{|thread| thread.stopping?}
    end

    def frozen(threshold)
      @list.select{|thread| thread.frozen?(threshold)}
    end

    def kill_frozen(threshold)
      ret = 0
      frozen(threshold).map{|t| ret+=1; t.thread.kill}
      ret
    end

    def prune_list
      ret = 0
      @list.reject! do |managed_thread|
        is_frozen = managed_thread.frozen?(FROZEN_THREADS_TIMEOUT)
        is_stopped = managed_thread.stopped?
        is_failed = managed_thread.stopped?
        ret += 1 if is_stopped || is_frozen
        is_stopped || is_frozen
      end
      ret
    end

    def set_log_level(log_level)
      running.map{|managed_thread| managed_thread.set_log_level(log_level)}
    end
    
    def get_first_thread_index
      running_indexes = active.map{|managed_thread| managed_thread.thread_index}
      Karma.logger.info { "Running indexes: #{running_indexes} " }
      ((0..1000).to_a - running_indexes).first
    end

    def add(blocks = {}, options = {})
      if options[:thread_index].nil?
        options[:thread_index] = get_first_thread_index
      end
      new_thread = Karma::Thread::ManagedThread.new(blocks, options)
      @list << new_thread
      until new_thread.inited?
        sleep 0.1
      end
      new_thread.start
    end

    def stop
      running.last.stop unless running.last.nil?
    end

    def stop_all
      running.each(&:stop)
      prune_list
      running.count
    end

    def reload_list
      @list = all.map{|t| t[:parent_class]}
    end

  end

end
