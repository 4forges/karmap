require 'karmap'

module Karma

  class Service
    attr_accessor :notifier, :engine, :init_status, :process_config, :thread_config, :sleep_time

    def initialize
      @notifier = case Karma.notifier
                    when 'queue'
                      Karma::Queue::QueueNotifier.new
                    when 'log'
                      Karma::Queue::LoggerNotifier.new
                  end
      @engine = case Karma.engine
                  when 'systemd'
                    Karma::Engine::Systemd.new
                end
      @thread_config = {
        num_threads: self.num_threads,
        log_level: self.log_level
      }
      @process_config = {
        min_running: self.min_running,
        max_running: self.max_running,
        memory_max: self.memory_max,
        cpu_quota: self.cpu_quota,
        auto_start: self.auto_start,
        auto_restart: self.auto_restart,
      }
      @init_status = {}
      @running = false
      @thread_pool = Karma::Thread::ThreadPool.new(Proc.new { perform })
      @thread_config_reader = Karma::Thread::SimpleTcpConfigReader.new(@thread_config)
      @sleep_time = 1
    end

    def name
      self.class.name.demodulize.downcase
    end

    def full_name
      "#{Karma.project_name}-#{name}"
    end

    def command
      "rails runner -e production \"o = #{self.class.name}.new; o.main_loop\"" # override if needed
    end

    def port
      5000 # override this
    end

    def log_location
      nil # override this
    end

    def perform
      # abstract, override this
      raise NotImplementedError
    end

    #################################################
    # default process configuration
    #################################################
    def min_running
      1 # override this
    end

    def max_running
      1 # override this
    end

    def memory_max
      nil # override this
    end

    def cpu_quota
      nil # override this
    end

    def auto_start
      true
    end

    def auto_restart
      true
    end

    def update_process_config(config)
      process_config.merge!(config)
    end
    #################################################

    #################################################
    # thread configuration
    #################################################
    def num_threads
      1 # override this
    end

    def log_level
      :info # override this
    end

    def update_thread_config(config)
      thread_config.merge!(config)
    end
    #################################################

    #################################################
    # abstract callbacks
    #################################################
    def before_start
      # abstract callback, override if needed
    end

    def after_start
      # abstract callback, override if needed
    end

    def before_stop
      # abstract callback, override if needed
    end

    def after_stop
      # abstract callback, override if needed
    end
    #################################################

    def main_loop
      Signal.trap('INT') do
        puts 'int trapped'
        thread_config[:running] = false
      end
      Signal.trap('TERM') do
        puts 'term trapped'
        thread_config[:running] = false
      end

      before_start
      @thread_config_reader.start
      thread_config[:running] = true
      after_start

      # notify queue after start
      message = engine.get_process_status_message($$)
      notifier.notify(message)

      while thread_config[:running] do

        # notify queue each loop
        message = engine.get_process_status_message($$)
        notifier.notify(message)

        thread_config.merge!(@thread_config_reader.config)
        @thread_pool.manage(thread_config)
        sleep(sleep_time)
      end

      before_stop
      @thread_pool.stop_all
      after_stop

      # notify queue after stop
      message = engine.get_process_status_message($$)
      notifier.notify(message)
    end

    def register
      message = Karma::Messages::ProcessRegisterMessage.new(
        host: ::Socket.gethostname,
        project: Karma.karma_project_id,
        service: full_name
      )
      notifier.notify(message)
    end


  end
end
