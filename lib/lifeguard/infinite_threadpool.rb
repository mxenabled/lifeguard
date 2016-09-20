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
        job_mutex = ::Mutex.new
        job_condition = ::ConditionVariable.new
        # Account for "weird" exceptions like Java Exceptions or higher up the chain
        # than what `rescue nil` will capture
        job_mutex.synchronize do
          new_thread = ::Thread.new(block, args) do |callable, call_args|
            job_mutex.synchronize do
              begin
                ::Thread.current[:__start_time_in_seconds__] = Time.now.to_i
                ::Thread.current.abort_on_exception = false

                callable.call(*call_args)
              ensure
                job_condition.signal
              end
            end
          end

          job_condition.wait(job_mutex)
        end
      else
        super(*args, &block)
      end

      return true
    end

    def kill!(*args)
      super
      @shutdown = true
    end

    def shutdown(*args)
      @shutdown = true
      super
    end

  end
end
