require 'thread'
require 'lifeguard/threadpool'

module Lifeguard
  class InfiniteThreadpool < ::Lifeguard::Threadpool

    def initialize(opts = {})
      super(opts)
      @shutdown = false
      @super_async_mutex = ::Mutex.new
    end

    def async(*args, &block)
      return false if @shutdown

      if busy?
        block.call(*args) rescue nil
      else
        super(args, &block)
      end

      return true
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
