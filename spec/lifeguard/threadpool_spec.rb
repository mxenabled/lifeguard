require 'spec_helper'

describe ::Lifeguard::Threadpool do

  subject { described_class.new(:pool_size => 5) }

  after(:each) do
    subject.kill!
    sleep(0.1)
  end

  describe "#busy?" do
    it "reports false when the busy_size < pool_size" do
      threadpool = described_class.new(:pool_size => 1, :reaping_interval => 1)
      expect(threadpool.busy?).to be false
    end

    it "reports true when the busy_size >= pool_size" do
      threadpool = described_class.new(:pool_size => 1, :reaping_interval => 1)
      threadpool.async do
        sleep(1)
      end

      expect(threadpool.busy?).to be true
    end
  end

  describe "#name" do
    let(:name) { "AWESOME_NAME" }

    it "allows a name to be set via an option" do
      threadpool = described_class.new(:name => name, :pool_size => 1, :reaping_interval => 1)
      expect(threadpool.name).to eq(name)
    end
  end

  describe "#timeout!" do
    it "doesn't timeout when no timeout set" do
      threadpool = described_class.new()
      threadpool.timeout?.should be false
    end

    it "does timeout when timeout set" do
      threadpool = described_class.new(:timeout => 30)
      threadpool.timeout?.should be true
    end

    it "uses the reaper to timeout threads that are all wiley" do
      threadpool = described_class.new(:timeout => 1, :reaping_interval => 1)
      threadpool.async do
        sleep(10)
      end

      threadpool.busy_size.should eq(1)
      sleep(4)
      threadpool.busy_size.should eq(0)
    end
  end

  describe '#kill!' do
    it 'attempts to kill all in-progress tasks' do
      @expected = false
      subject.async{ sleep(1); @expected = true }
      sleep(0.1)
      subject.kill!
      sleep(1)
      @expected.should be false
    end

    it 'rejects all pending tasks' do
      @expected = false
      subject.async{ sleep(0.5) }
      subject.async{ sleep(0.5); @expected = true }
      sleep(0.1)
      subject.kill!
      sleep(1)
      @expected.should be false
    end

    it 'kills all threads' do
      before_thread_count = Thread.list.size
      100.times { subject.async{ sleep(1) } }
      sleep(0.1)
      Thread.list.size.should > before_thread_count
      subject.kill!
      sleep(0.1)
      Thread.list.size.should eq(before_thread_count + 1) # +1 for the reaper
    end
  end

  describe '#async' do
    it 'raises an exception if no block is given' do
      expect { subject.async }.to raise_error
    end

    it 'returns true when the block is added to the queue' do
      subject.async{ sleep }.should be true
    end

    it 'calls the block with the given arguments' do
      @expected = nil
      subject.async(1, 2, 3) do |a, b, c|
        @expected = a + b + c
      end
      sleep(0.5)
      @expected.should eq 6
    end
  end
end
