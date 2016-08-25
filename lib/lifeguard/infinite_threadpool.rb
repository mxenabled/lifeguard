require 'thread'
require 'lifeguard/threadpool'

module Lifeguard
  class InfiniteThreadpool < ::Lifeguard::Threadpool

    def initialize(opts = {})
      super(opts)
      @queued_jobs = ::Queue.new
      @shutdown = false
    end

    # Handle to original async method
    # for check_queued_jobs to use directly
    alias_method :super_async, :async

    def async(*args, &block)
      return false if @shutdown

      check_queued_jobs
      job_started = super

      unless job_started
        @queued_jobs << { :args => args, :block => block }
      end

      job_started
    end

    def check_queued_jobs
      return if busy?
      return if @queued_jobs.size <= 0

      queued_job = @queued_jobs.pop
      super_async(*queued_job[:args], &queued_job[:block])
      check_queued_jobs
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
