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
      end
    rescue
      retry
    end

  end
end
