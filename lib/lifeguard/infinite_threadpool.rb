require 'thread'
require 'lifeguard/threadpool'

module Lifeguard
  class InfiniteThreadpool < ::Lifeguard::Threadpool

    def initialize(opts = {})
      super(opts)
      @queued_jobs = ::Queue.new
      @shutdown = false
      @super_async_mutex = ::Mutex.new
      @scheduler = create_scheduler
    end

    # Handle to original async method # for check_queued_jobs to use directly
    alias_method :super_async, :async

    def async(*args, &block)
      return false if @shutdown

      if @queued_jobs.size > 1000
        block.call(*args) rescue nil
      else
        @queued_jobs << { :args => args, :block => block }
      end

      return true
    end

    def shutdown(shutdown_timeout = 30)
      @shutdown = true
      @scheduler.join
      super(shutdown_timeout)
    end

    def create_scheduler
      Thread.new do
        while !@shutdown || @queud_jobs.size > 0
          if busy?
            sleep 0.1
          else
            queued_job = @queued_jobs.pop
            super_async(*queued_job[:args], &queued_job[:block])
          end
        end
      end
    end

    def kill!(*args)
      super
      @shutdown = true
    end

    def on_thread_exit(thread)
      return_value = super
      check_queued_jobs
      return_value
    end

    def prune_busy_threads
      response = super
      check_queued_jobs
      response
    end

    def shutdown(*args)
      @shutdown = true
      super
    end

  end
end
