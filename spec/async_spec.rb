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

    it 'blocks until resolved' do
      time_start = Time.now

      Async { |t| t.sleep 2 ; promise.fulfill }
      promise.value!

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
  end
end
