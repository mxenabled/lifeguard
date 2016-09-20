require 'thread'
require 'securerandom'

module Lifeguard
  class Threadpool
    DEFAULT_REAPING_INTERVAL = 5 # in seconds
    DEFAULT_POOL_SIZE = 2

    attr_accessor :name, :options, :pool_size

    ##
    # Constructor
    #
    def initialize(opts = {})
      @options = opts
      @name = opts[:name] || ::SecureRandom.uuid
      @pool_size = opts[:pool_size] || DEFAULT_POOL_SIZE

      # Important info about "timeout", it is controlled by the reaper
      # so you're threads won't timeout immediately, they will wait for
      # the reaper to run.  Make sure you account for reaper interval
      # in how you want timeout to work, it may be a bit unexpected in 
      # it's tardiness of timing out threads
      #
      @timeout = opts[:timeout]
      @mutex = ::Mutex.new
      @busy_threads = ThreadGroup.new

      restart_reaper_unless_alive
    end

    ##
    # Public Instance Methods
    #
    def busy?
      busy_size >= pool_size
    end

    def busy_size
      @busy_threads.list.size
    end

    def kill!
      @mutex.synchronize do
        @busy_threads.list.each { |busy_thread| busy_thread.kill }
      end
    end

    def async(*args, &block)
      queued_the_work = false
      restart_reaper_unless_alive

      unless block
        raise "Threadpool#async must be passed a block"
      end

      @mutex.synchronize do
        if busy_size < pool_size
          queued_the_work = true

          @busy_threads.add ::Thread.new(block, args, self) { |callable, call_args, parent|
            ::Thread.current.abort_on_exception = false
            ::Thread.current[:__start_time_in_seconds__] = Time.now.to_i
            callable.call(*call_args) # should we check the args? pass args?
          }
        end

        queued_the_work
      end
    end

    def shutdown(shutdown_timeout = 3)
      kill_at = Time.now.to_f + shutdown_timeout

      @mutex.synchronize do
        sleep 0.01 while busy_size > 0 && Time.now.to_f < kill_at
        @busy_threads.list.each { |busy_thread| busy_thread.kill }
      end
    end

    def timeout!
      return unless timeout?

      @mutex.synchronize do
        @busy_threads.list.each do |busy_thread|
          if (Time.now.to_i - busy_thread[:__start_time_in_seconds__] > @timeout)
            busy_thread.kill
          end
        end
      end
    end

    def timeout?
      !!@timeout
    end

    private

    ##
    # Private Instance Methods
    #
    def restart_reaper_unless_alive
      return if @reaper && @reaper.alive?

      @reaper = ::Lifeguard::Reaper.new(self, options[:reaping_interval] || DEFAULT_REAPING_INTERVAL)
    end

  end
end
