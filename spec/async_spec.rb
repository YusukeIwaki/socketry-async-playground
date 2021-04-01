require 'spec_helper'

require './async_utils'
require 'async'
require 'timeout'

RSpec.describe 'socketry/sync' do
  describe 'Promise' do
    around do |example|
      Async { example.run }
    end
    let(:promise) { Promise.new }

    it 'is not resolved on initialize' do
      expect(promise).not_to be_resolved
      expect(promise).not_to be_fulfilled
      expect(promise).not_to be_rejected
    end

    it 'blocks until fulfilled' do
      time_start = Time.now

      Async { |t| t.sleep 2 ; promise.fulfill }
      promise.value!

      expect(Time.now - time_start).to be > 1
    end

    it 'blocks until rejected' do
      time_start = Time.now

      Async { |t| t.sleep 2 ; promise.reject("invalid") }
      expect { promise.value! }.to raise_error(/invalid/)

      expect(Time.now - time_start).to be > 1
    end

    it 'returns soon if already resolved' do
      promise.fulfill

      Timeout.timeout(1) { promise.value! }
    end

    it "doesn't raise on reject" do
      expect { promise.reject("error!") }.not_to raise_error
    end

    it 'raises Rejection error for the result of reject' do
      promise.reject("Error!")
      expect { promise.value! }.to raise_error(Promise::Rejection)
    end

    it 'raises Rejection error for the result of reject' do
      promise.reject(ArgumentError.new("invalid"))
      expect { promise.value! }.to raise_error(ArgumentError)
    end

    it 'returns nil on fulfill without arg' do
      promise.fulfill
      Timeout.timeout(1) { expect(promise.value!).to be_nil }
    end

    it 'returns value on fulfill with arg' do
      promise.fulfill(123)
      Timeout.timeout(1) { expect(promise.value!).to eq(123) }
    end

    it 'can force_stop' do
      Async { |t| t.sleep 1 ; promise.send(:force_stop) }
      Timeout.timeout(2) {
        expect { promise.value! }.to raise_error(Promise::Cancel)
      }
    end
  end

  describe 'Future' do
    around do |example|
      Async { example.run }
    end

    it 'is not resolved on initialize' do
      future = Future.new { |t| t.sleep 2 }
      expect(future).not_to be_resolved
      expect(future).not_to be_fulfilled
      expect(future).not_to be_rejected
    end

    it 'is resolved on success' do
      future = Future.new { 123 }
      expect(future).to be_resolved
      expect(future).to be_fulfilled
      expect(future).not_to be_rejected
      expect(future.value!).to eq(123)
    end

    it 'is rejected on error' do
      future = Future.new { raise 'invalid' }
      expect(future).to be_resolved
      expect(future).not_to be_fulfilled
      expect(future).to be_rejected
      expect { future.value! }.to raise_error(/invalid/)
    end

    it 'can force_stop' do
      future = Future.new { |t| t.sleep 3 ; raise 'invalid' }
      Async { |t| t.sleep 1 ; future.send(:force_stop) }
      Timeout.timeout(2) {
        expect { future.value! }.to raise_error(Future::Cancel)
      }
    end
  end

  describe 'SimpleAwaitAll' do
    around do |example|
      Async { example.run }
    end

    it 'wait all result' do
      all = SimpleAwaitAll.new(
        Future.new { |t| t.sleep 2 ; 2 },
        Future.new { |t| t.sleep 3 ; 3 },
        Future.new { |t| 1 },
      )
      time_start = Time.now
      expect(all.value!).to eq([2, 3, 1])
      elapsed_time = Time.now - time_start
      expect(elapsed_time).to be > 2
      expect(elapsed_time).to be < 4
    end

    xit 'wait first rejection' do
      items = [
        Promise.new,
        Future.new { |t| t.sleep 2 ; raise "Boom" },
        Future.new { |t| 1 },
      ]
      all = AwaitAll.new(*items)
      time_start = Time.now
      expect { all.value! }.to raise_error(/Boom/)
      elapsed_time = Time.now - time_start
      expect(elapsed_time).to be > 1
      expect(elapsed_time).to be < 3
      expect(items.first).to be_resolved
      expect(items.last).to be_resolved
    end
  end

  describe 'AwaitAll' do
    around do |example|
      Async { example.run }
    end

    it 'wait all result' do
      all = AwaitAll.new(
        Future.new { |t| t.sleep 2 ; 2 },
        Future.new { |t| t.sleep 3 ; 3 },
        Future.new { |t| 1 },
      )
      time_start = Time.now
      expect(all.value!).to eq([2, 3, 1])
      elapsed_time = Time.now - time_start
      expect(elapsed_time).to be > 2
      expect(elapsed_time).to be < 4
    end

    it 'wait first rejection' do
      items = [
        Promise.new,
        Future.new { |t| t.sleep 2 ; raise "Boom" },
        Future.new { |t| 1 },
      ]
      all = AwaitAll.new(*items)
      time_start = Time.now
      expect { all.value! }.to raise_error(/Boom/)
      elapsed_time = Time.now - time_start
      expect(elapsed_time).to be > 1
      expect(elapsed_time).to be < 3
      expect(items.first).to be_resolved
      expect(items.last).to be_resolved
    end
  end

  describe 'AwaitAny' do
    around do |example|
      Async { example.run }
    end

    it 'wait first result' do
      items = [
        Future.new { |t| t.sleep 2 ; raise "error-2" },
        Future.new { |t| t.sleep 3 ; raise "error-3" },
        Future.new { |t| 1 },
      ]
      all = AwaitAny.new(*items)
      Timeout.timeout(1) { all.value! }
      expect(all.value!).to eq(1)
      expect(items).to all(be_resolved)
    end

    it 'wait first rejection' do
      items = [
        Promise.new,
        Future.new { |t| t.sleep 2 ; raise "Boom" },
        Future.new { |t| t.sleep 3 ; 3 },
      ]
      all = AwaitAny.new(*items)
      time_start = Time.now
      expect { all.value! }.to raise_error(/Boom/)
      elapsed_time = Time.now - time_start
      expect(elapsed_time).to be > 1
      expect(elapsed_time).to be < 3
      expect(items).to all(be_resolved)
    end
  end
end
