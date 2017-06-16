module Karma::Thread

  class ThreadPool

    attr_accessor :thread
    cattr_accessor :list, :thread_index

    # blocks:
    # :starting
    # :finishing
    # :running
    # :performance

    def initialize(blocks, options = {})
      @blocks = blocks
      @list = []
      @thread_index = 0
    end

    def manage(config = {})
      @default_config ||= config
      @current_config = config || @default_config

      max_workers = @current_config[:num_threads]||0
      log_level = @current_config[:log_level]||0

      Karma.logger.debug{ 'Pruning stopped threads...' }
      num_pruned = prune_list
      Karma.logger.debug{ num_pruned > 0 ? "#{num_pruned} pruned" : "Nothing to prune" }

      Karma.logger.debug{ "Active size: #{active.size} - max_workers: #{max_workers}" }
      while (active.size) < max_workers
        Karma.logger.debug{ "Adding new thread..." }
        add_and_start({ running_sleep_time: @current_config[:sleep_time] })
      end
      while (active.size) > max_workers
        Karma.logger.debug{ "Stopping thread..." }
        stop
      end

      Karma.logger.debug{ "Set log level to #{log_level}"}
      set_log_level(log_level)
      
      Karma.logger.debug{ "Active threads:"}
      active.each do |t|
        Karma.logger.debug{ t.to_s }
      end
      true
    end

    # Call this method repeatedly inside fetching jobs that might take more than 1.hour (like garbage collectors)
    # to avoid getting killed.
    def self.signal_alive
      Thread.current[:last_running_at] = Time.now
      if Thread.current[:last_logged_at].nil? || (Time.now.to_i - Thread.current[:last_logged_at].to_i) > 10
        Thread.current[:logger].info 'I\'m alive' if Thread.current[:logger].present?
        Thread.current[:last_logged_at] = Thread.current[:last_running_at]
      end
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

    def prune_list
      ret = 0
      @list.reject! do |managed_thread|
        is_stopped = managed_thread.stopped?
        is_failed = managed_thread.stopped?
        ret += 1 if is_stopped
        is_stopped
      end
      ret
    end

    def set_log_level(log_level)
      running.each{|managed_thread| managed_thread.set_log_level(log_level)}
    end

    def get_first_thread_index
      running_indexes = active.map{|managed_thread| managed_thread.thread_index}
      Karma.logger.info{ "Running indexes: #{running_indexes}" }
      ((0..1000).to_a - running_indexes).first
    end

    def add_and_start(options = {})
      if options[:thread_index].nil?
        options[:thread_index] = get_first_thread_index
      end
      new_thread = Karma::Thread::ManagedThread.new(@blocks, options)
      @list << new_thread
      until new_thread.inited?
        sleep 0.1
      end
      new_thread.start
      until new_thread.running?
        Karma.logger.debug{ "Waiting for thread to start" }
        sleep 0.1
      end
      Karma.logger.debug{ "pid: #{$$} thread: #{new_thread.thread[:thread_index]} status: #{new_thread.thread.status}" }
      new_thread
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

    def average_execution_time
      execution_times = []
      running.each do |t|
        execution_times << t.execution_time if !t.execution_time.nil?
      end
      execution_times.size > 0 ? execution_times.sum.to_f / execution_times.size.to_f : 0
    end

    def average_performance_execution_time
      performance_execution_times = []
      running.each do |t|
        performance_execution_times << t.performance_execution_time if !t.performance_execution_time.nil?
      end
      performance_execution_times.size > 0 ? performance_execution_times.sum.to_f / performance_execution_times.size.to_f : 0
    end

    def average_performance
      performances = []
      running.each do |t|
        performances << t.performance if !t.performance.nil?
      end
      performances.size > 0 ? performances.sum.to_f / performances.size.to_f : 0
    end

  end

end
