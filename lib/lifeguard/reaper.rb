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

    def run!
      loop do
        sleep(@reaping_interval)
        @threadpool.prune_busy_threads if @threadpool
        @threadpool.timeout! if @threadpool
      end
    rescue
      retry
    end
  end
end
