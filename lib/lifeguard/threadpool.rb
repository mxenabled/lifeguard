require 'thread'

module Lifeguard
  class Threadpool
    DEFAULT_REAPING_INTERVAL = 5 # in seconds
    DEFAULT_POOL_SIZE = 2

    attr_accessor :options, :pool_size

    ##
    # Constructor
    #
    def initialize(opts = {})
      @options = opts
      @pool_size = opts[:pool_size] || DEFAULT_POOL_SIZE

      # Important info about "timeout", it is controlled by the reaper
      # so you're threads won't timeout immediately, they will wait for
      # the reaper to run.  Make sure you account for reaper interval
      # in how you want timeout to work, it may be a bit unexpected in 
      # it's tardiness of timing out threads
      #
      @timeout = opts[:timeout]
      @mutex = ::Mutex.new
      @busy_threads = []

      restart_reaper_unless_alive
    end

    ##
    # Public Instance Methods
    #
    def busy?
      busy_size >= pool_size
    end

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
      restart_reaper_unless_alive

      unless block
        raise "Threadpool#async must be passed a block"
      end

      @mutex.synchronize do
        prune_busy_threads_without_mutex

        if busy_size < pool_size
          queued_the_work = true

          @busy_threads << ::Thread.new(block, args, self) do |callable, call_args, parent|
            begin
              ::Thread.current[:__start_time_in_seconds__] = Time.now.to_i
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

    def shutdown(shutdown_timeout = 0)
      @mutex.synchronize do
        prune_busy_threads_without_mutex

        if @busy_threads.size > 0
          # Cut the shutdown_timeout by 10 and prune while things finish before the kill
          (shutdown_timeout/10).times do 
            sleep (shutdown_timeout / 10.0)
            prune_busy_threads_without_mutex
            break if busy_size == 0
          end

          sleep(shutdown_timeout/10)
          @busy_threads.each { |busy_thread| busy_thread.kill }
        end

        prune_busy_threads_without_mutex
      end
    end

    def timeout!
      return unless timeout?

      @mutex.synchronize do
        @busy_threads.each do |busy_thread|
          if (Time.now.to_i - busy_thread[:__start_time_in_seconds__] > @timeout)
            busy_thread.kill
          end
        end

        prune_busy_threads_without_mutex
      end
    end

    def timeout?
      !!@timeout
    end

    private

    ##
    # Private Instance Methods
    #
    def prune_busy_threads_without_mutex
      @busy_threads.select!(&:alive?)
    end

    def restart_reaper_unless_alive
      return if @reaper && @reaper.alive?

      @reaper = ::Lifeguard::Reaper.new(self, options[:reaping_interval] || DEFAULT_REAPING_INTERVAL)
    end

  end
end
