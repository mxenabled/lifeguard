require 'spec_helper'

describe ::Lifeguard::Threadpool do

  subject { described_class.new(:pool_size => 5) }

  after(:each) do
    subject.kill!
    sleep(0.1)
  end

  describe '#kill!' do
    it 'attempts to kill all in-progress tasks' do
      @expected = false
      subject.async{ sleep(1); @expected = true }
      sleep(0.1)
      subject.kill!
      sleep(1)
      @expected.should be_false
    end

    it 'rejects all pending tasks' do
      @expected = false
      subject.async{ sleep(0.5) }
      subject.async{ sleep(0.5); @expected = true }
      sleep(0.1)
      subject.kill!
      sleep(1)
      @expected.should be_false
    end

    it 'kills all threads' do
      before_thread_count = Thread.list.size
      100.times { subject.async proc{ sleep(1) } }
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
      subject.async{ sleep }.should be_true
    end

    it 'calls the block with the given arguments' do
      @expected = nil
      subject.async(1, 2, 3) do |a, b, c|
        @expected = a + b + c
      end
      sleep(0.1)
      @expected.should eq 6
    end

    it 'rejects the block while shutting down' do
      subject.async{ sleep(1) }
      subject.shutdown
      @expected = nil
      subject.async(1, 2, 3) do |a, b, c|
        @expected = a + b + c
      end
      @expected.should be_nil
    end

    it 'returns false while shutting down' do
      subject.async{ sleep(1) }
      subject.shutdown
      subject.async{ nil }.should be_false
    end

    it 'rejects the block once shutdown' do
      subject.shutdown
      @expected = nil
      subject.async(1, 2, 3) do |a, b, c|
        @expected = a + b + c
      end
      @expected.should be_nil
    end

    it 'returns false once shutdown' do
      subject.async{ nil }
      subject.shutdown
      sleep(0.1)
      subject.async{ nil }.should be_false
    end
  end
end
