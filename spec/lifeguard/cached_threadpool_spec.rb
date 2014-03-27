require 'spec_helper'

describe ::Lifeguard::CachedThreadpool do

  subject { described_class.new(:max_threads => 5) }

  after(:each) do
    subject.kill
    sleep(0.1)
  end

  describe '#initialize' do
    it 'raises an exception when the pool size is less than one' do
      expect {
        described_class.new(:max => 0)
      }.to raise_error
    end

    it 'raises an exception when the pool size is greater than MAX_POOL_SIZE' do
      expect {
        described_class.new(:max => described_class::MAX_POOL_SIZE + 1)
      }.to raise_error
    end
  end

  describe '#length' do
    it 'returns zero for a new thread pool' do
      subject.length.should eq 0
    end

    it 'returns the length of the subject when running' do
      5.times{ sleep(0.1); subject << proc{ sleep(1) } }
      subject.length.should eq 5
    end

    it 'returns zero once shut down' do
      subject.shutdown
      subject.length.should eq 0
    end
  end

  describe '#running?' do
    it 'returns true when the thread pool is running' do
      subject.should be_running
    end

    it 'returns false when the thread pool is shutting down' do
      subject.post{ sleep(1) }
      subject.shutdown
      subject.should_not be_running
    end

    it 'returns false when the thread pool is shutdown' do
      subject.shutdown
      subject.should_not be_running
    end

    it 'returns false when the thread pool is killed' do
      subject.shutdown
      subject.should_not be_running
    end
  end

  describe '#shutdown' do
    it 'stops accepting new tasks' do
      subject.post{ sleep(1) }
      sleep(0.1)
      subject.shutdown
      @expected = false
      subject.post{ @expected = true }.should be_false
      sleep(1)
      @expected.should be_false
    end

    it 'allows in-progress tasks to complete' do
      @expected = false
      subject.post{ @expected = true }
      sleep(0.1)
      subject.shutdown
      sleep(1)
      @expected.should be_true
    end

    it 'allows pending tasks to complete' do
      @expected = false
      subject.post{ sleep(0.2) }
      subject.post{ sleep(0.2); @expected = true }
      sleep(0.1)
      subject.shutdown
      sleep(1)
      @expected.should be_true
    end

    it 'allows threads to exit normally' do
      10.times{ subject << proc{ nil } }
      subject.length.should > 0
      sleep(0.1)
      subject.shutdown
      sleep(1)
      subject.length.should == 0
    end
  end

  describe '#kill' do
    it 'stops accepting new tasks' do
      subject.post{ sleep(1) }
      sleep(0.1)
      subject.kill
      @expected = false
      subject.post{ @expected = true }.should be_false
      sleep(1)
      @expected.should be_false
    end

    it 'attempts to kill all in-progress tasks' do
      @expected = false
      subject.post{ sleep(1); @expected = true }
      sleep(0.1)
      subject.kill
      sleep(1)
      @expected.should be_false
    end

    it 'rejects all pending tasks' do
      @expected = false
      subject.post{ sleep(0.5) }
      subject.post{ sleep(0.5); @expected = true }
      sleep(0.1)
      subject.kill
      sleep(1)
      @expected.should be_false
    end

    it 'kills all threads' do
      before_thread_count = Thread.list.size
      100.times { subject << proc{ sleep(1) } }
      sleep(0.1)
      Thread.list.size.should > before_thread_count
      subject.kill
      sleep(0.1)
      Thread.list.size.should eq(before_thread_count + 1) # +1 for the reaper
    end
  end

  describe '#post' do
    it 'raises an exception if no block is given' do
      expect { subject.post }.to raise_error
    end

    it 'returns true when the block is added to the queue' do
      subject.post{ sleep }.should be_true
    end

    it 'calls the block with the given arguments' do
      @expected = nil
      subject.post(1, 2, 3) do |a, b, c|
        @expected = a + b + c
      end
      sleep(0.1)
      @expected.should eq 6
    end

    it 'rejects the block while shutting down' do
      subject.post{ sleep(1) }
      subject.shutdown
      @expected = nil
      subject.post(1, 2, 3) do |a, b, c|
        @expected = a + b + c
      end
      @expected.should be_nil
    end

    it 'returns false while shutting down' do
      subject.post{ sleep(1) }
      subject.shutdown
      subject.post{ nil }.should be_false
    end

    it 'rejects the block once shutdown' do
      subject.shutdown
      @expected = nil
      subject.post(1, 2, 3) do |a, b, c|
        @expected = a + b + c
      end
      @expected.should be_nil
    end

    it 'returns false once shutdown' do
      subject.post{ nil }
      subject.shutdown
      sleep(0.1)
      subject.post{ nil }.should be_false
    end

    it 'aliases #<<' do
      @expected = false
      subject << proc { @expected = true }
      sleep(0.1)
      @expected.should be_true
    end
  end

  describe 'worker creation and caching' do
    it 'creates new workers when there are none available' do
      subject.length.should eq 0
      5.times{ sleep(0.1); subject << proc{ sleep } }
      sleep(1)
      subject.length.should eq 5
    end

    it 'uses existing idle threads' do
      5.times{ subject << proc{ sleep(0.1) } }
      sleep(1)
      subject.length.should >= 5
      3.times{ subject << proc{ sleep } }
      sleep(0.1)
      subject.length.should >= 5
    end

    it 'never creates more than :max_threads threads' do
      pool = described_class.new(:max => 5)
      100.times{ sleep(0.01); pool << proc{ sleep } }
      sleep(0.1)
      pool.length.should eq 5
      pool.kill
    end

    it 'sets :max_threads to MAX_POOL_SIZE when not given' do
      described_class.new.max_threads.should eq described_class::MAX_POOL_SIZE
    end
  end

  describe 'garbage collection' do
    subject{ described_class.new(:gc_interval => 1, :idletime => 1) }

    it 'removes from pool any thread that has been idle too long' do
      3.times { subject << proc{ sleep(0.1) } }
      subject.length.should eq 3
      sleep(2)
      subject << proc{ nil }
      subject.length.should < 3
    end

    it 'removed from pool any dead thread' do
      3.times { subject << proc{ sleep(0.1); raise Exception } }
      subject.length.should == 3
      sleep(2)
      subject << proc{ nil }
      subject.length.should < 3
    end
  end
end
