require 'spec_helper'

require './async_utils'
require 'async'
require 'timeout'

RSpec.describe 'socketry/sync' do
  describe 'Promiseっぽいの' do
    around do |example|
      Async { example.run }
    end

    it 'is not resolved on initialize' do
      promise = Promise.new
      expect(promise).not_to be_resolved
      expect(promise).not_to be_fulfilled
      expect(promise).not_to be_rejected
    end

    it 'blocks until resolved' do
      promise = Promise.new

      time_start = Time.now

      Async { sleep 2 ; promise.fulfill }
      promise.value!

      expect(Time.now - time_start).to be > 1
    end

    it 'returns soon if already resolved' do
      promise = Promise.new
      promise.fulfill

      Timeout.timeout(1) { promise.value! }
    end

    it "doesn't raise on reject" do
      promise = Promise.new
      expect { promise.reject("error!") }.not_to raise_error
    end

    it 'raises Rejection error for the result of reject' do
      promise = Promise.new
      promise.reject("Error!")
      expect { promise.value! }.to raise_error(Promise::Rejection)
    end

    it 'raises Rejection error for the result of reject' do
      promise = Promise.new
      promise.reject(ArgumentError.new("invalid"))
      expect { promise.value! }.to raise_error(ArgumentError)
    end

    it 'returns nil on fulfill without arg' do
      promise = Promise.new
      promise.fulfill
      Timeout.timeout(1) { expect(promise.value!).to be_nil }
    end

    it 'returns value on fulfill with arg' do
      promise = Promise.new
      promise.fulfill(123)
      Timeout.timeout(1) { expect(promise.value!).to eq(123) }
    end
  end
end
