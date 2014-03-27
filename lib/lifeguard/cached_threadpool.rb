module Lifeguard
  class CachedThreadpool

    MIN_POOL_SIZE = 1
    MAX_POOL_SIZE = 256

    DEFAULT_REAPING_INTERVAL = 5 # in seconds
    DEFAULT_THREAD_IDLETIME = 60 # in seconds

    attr_accessor :max_threads

    ##
    # Constructor
    #
    def initialize(opts = {})
      @idletime = (opts[:idletime] || DEFAULT_THREAD_IDLETIME).to_i
      raise ::ArgumentError.new('idletime must be greater than zero') if @idletime <= 0

      @max_threads = opts[:max_threads] || opts[:max] || MAX_POOL_SIZE
      if @max_threads < MIN_POOL_SIZE || @max_threads > MAX_POOL_SIZE
        raise ::ArgumentError.new("size must be from #{MIN_POOL_SIZE} to #{MAX_POOL_SIZE}")
      end

      @state = :running
      @pool = []
      @mutex = ::Mutex.new

      @busy = []
      @idle = []

      @reaper = ::Lifeguard::Reaper.new(self, opts[:reaping_interval] || DEFAULT_REAPING_INTERVAL)
    end

    ##
    # Public Instance Methods
    #
    def <<(block)
      self.post(&block)
      return self
    end

    def busy_size
      @busy.size
    end

    def idle_size
      @idle.size
    end

    def kill
      @mutex.synchronize do
        break if @state == :shutdown
        @state = :shutdown
        @idle.each{ |worker| worker.kill }
        @busy.each{ |worker| worker.kill }
      end
    end

    def length
      @mutex.synchronize do
        @state == :running ? @busy.length + @idle.length : 0
      end
    end

    def on_worker_exit(worker)
      @mutex.synchronize do
        @idle.delete(worker)
        @busy.delete(worker)
        if @idle.empty? && @busy.empty? && @state != :running
          @state = :shutdown
        end
      end
    end
    
    def on_end_task(worker)
      @mutex.synchronize do
        break unless @state == :running
        @busy.delete(worker)
        @idle.push(worker)
      end
    end

    def post(*args, &block)
      raise ArgumentError.new('no block given') if block.nil?
      @mutex.synchronize do
        break false unless @state == :running

        if @idle.empty?
          if @idle.length + @busy.length < @max_threads
            worker = create_worker_thread
          else
            worker = @busy.shift
          end
        else
          worker = @idle.pop
        end

        @busy.push(worker)
        worker.signal(*args, &block)

        prune_idle_workers_without_mutex
        true
      end
    end

    def prune_busy_workers
      @mutex.synchronize do
        prune_busy_workers_without_mutex
      end
    end

    def prune_idle_workers
      @mutex.synchronize do
        prune_idle_workers_without_mutex
      end
    end

    def running?
      return @state == :running
    end

    def shutdown
      @mutex.synchronize do
        break unless @state == :running
        if @idle.empty? && @busy.empty?
          @state = :shutdown
        else
          @state = :shuttingdown
          @idle.each{ |worker| worker.stop }
          @busy.each{ |worker| worker.stop }
        end
      end
    end

    def size
      @mutex.synchronize do
        @state == :running ? @busy.length + @idle.length : 0
      end
    end

    private

    ##
    # Private Instance Methods
    #
    def create_worker_thread
      worker = ::Lifeguard::Worker.new(self)

      ::Thread.new(worker, self) do |worker, parent|
        begin
          ::Thread.current.abort_on_exception = false
          worker.run
        ensure
          parent.on_worker_exit(worker)
        end
      end

      return worker
    end

    def prune_busy_workers_without_mutex
      @busy.reject!(&:dead?)
    end

    def prune_idle_workers_without_mutex
      @idle.reject! do |worker|
        if worker.idletime > @idletime
          worker.stop
          true
        else
          worker.dead?
        end
      end
    end
  end
end
