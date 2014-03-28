module Lifeguard
  class Reaper
    ##
    # Constructor
    #
    def initialize(threadpool, reaping_interval)
      @threadpool = threadpool
      @reaping_interval = reaping_interval
      @thread = ::Thread.new { self.run! }
    end

    ##
    # Public Instance Methods
    #
    def alive?
      @thread.alive?
    end

    def reap!
      @threadpool.prune_busy_threads
    end

    def run!
      loop do
        sleep(@reaping_interval)
        reap!
        timeout!
        ready_thread_count = @threadpool.pool_size - @threadpool.busy_size
        
        if ready_thread_count > 0 && @threadpool.respond_to?(:check_queued_jobs)
          ready_thread_count.times do
            @threadpool.check_queued_jobs
          end
        end
      end
    rescue
      retry
    end

    def timeout!
      @threadpool.timeout!
    end

  end
end
