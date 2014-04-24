require 'thread'
require 'lifeguard/threadpool'

module Lifeguard
  class InfiniteThreadpool < ::Lifeguard::Threadpool

    def initialize(opts = {})
      super(opts)
      @queued_jobs = []
      @job_queue_mutex = ::Mutex.new
      @shutdown = false
    end

    def async(*args, &block)
      return false if @shutdown

      job_started = super

      unless job_started
        @queued_jobs << { :args => args, :block => block }
      end

      job_started
    end

    def check_queued_jobs
      if @queued_jobs.size > 0
        queued_job = @queued_jobs.pop
        async(*queued_job[:args], &queued_job[:block])
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

    def shutdown(*args)
      @shutdown = true
      super
    end

  end
end
