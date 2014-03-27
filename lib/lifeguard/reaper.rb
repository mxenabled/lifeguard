module Lifeguard
  class Reaper

    ##
    # Constructor
    #
    def initialize(cached_threadpool, reaping_interval)
      @cached_threadpool = cached_threadpool
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
      @cached_threadpool.prune_busy_workers
      @cached_threadpool.prune_idle_workers
    end

    def run!
      loop do
        sleep(@reaping_interval)
        reap!
      end
    end

  end
end
