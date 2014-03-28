require 'thread'

module Lifeguard
  class Threadpool
    DEFAULT_REAPING_INTERVAL = 5 # in seconds
    DEFAULT_POOL_SIZE = 2

    attr_accessor :pool_size

    ##
    # Constructor
    #
    def initialize(opts = {})
      @pool_size = opts[:pool_size] || DEFAULT_POOL_SIZE
      @mutex = ::Mutex.new
      @busy_threads = []

      @reaper = ::Lifeguard::Reaper.new(self, opts[:reaping_interval] || DEFAULT_REAPING_INTERVAL)
    end

    ##
    # Public Instance Methods
    #
    def busy_size
      @busy_threads.size
    end

    def kill!
      @mutex.synchronize do
        prune_busy_threads_without_mutex
        @busy_threads.each { |busy_thread| busy_thread.kill }
        prune_busy_threads_without_mutex
      end
    end

    def on_thread_exit(thread)
      @mutex.synchronize do
        @busy_threads.delete(thread)
      end
    end

    def async(*args, &block)
      queued_the_work = false

      unless block
        raise "Threadpool#async must be passed a block"
      end

      @mutex.synchronize do
        prune_busy_threads_without_mutex

        if busy_size < pool_size
          queued_the_work = true

          @busy_threads << ::Thread.new(block, args, self) do |callable, call_args, parent|
            begin
              ::Thread.current.abort_on_exception = false
              callable.call(*call_args) # should we check the args? pass args?
            ensure
              parent.on_thread_exit(::Thread.current)
            end
          end
        end

        prune_busy_threads_without_mutex
        queued_the_work
      end
    end

    def prune_busy_threads
      @mutex.synchronize do
        prune_busy_threads_without_mutex
      end
    end

    def shutdown(timeout = 0)
      @mutex.synchronize do
        prune_busy_threads_without_mutex

        if @busy_threads.size > 0
          # Cut the timeout by 10 and prune while things finish before the kill
          (timeout/10).times do 
            sleep (timeout / 10.0)
            prune_busy_threads_without_mutex
            break if busy_size == 0
          end

          sleep(timeout/10)
          @busy_threads.each { |busy_thread| busy_thread.kill }
        end

        prune_busy_threads_without_mutex
      end
    end

    private

    ##
    # Private Instance Methods
    #
    def prune_busy_threads_without_mutex
      @busy_threads.select!(&:alive?)
    end

  end
end
