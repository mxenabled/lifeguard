require 'thread'
require 'lifeguard/threadpool'

module Lifeguard
  class InfiniteThreadpool < ::Lifeguard::Threadpool

    def initialize(opts = {})
      super(opts)
      @queued_jobs = []
      @job_queue_mutex = ::Mutex.new
    end

    def async(*args, &block)
      job_started = super

      unless job_started
        @queued_jobs << { :args => args, :block => block }
      end
    end

    def on_thread_exit(thread)
      super
    end

    def check_queued_jobs
      if @queued_jobs.size > 0
        queued_job = @queued_jobs.pop
        async(queued_job[:args], &queued_job[:block])
      end
    end

  end
end
