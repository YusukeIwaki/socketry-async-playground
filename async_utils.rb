require 'async/condition'

class Promise
  def initialize
    @fulfilled = false
    @resolved = false
    @value = nil
  end

  def fulfill(value = nil)
    raise ArgumentError.new('already resolved') if @resolved

    @fulfilled = true
    @resolved = true
    @value = value
    @notification&.signal(@value)

    nil
  end

  class Rejection < StandardError ; end
  class Cancel < StandardError ; end

  def reject(error)
    raise ArgumentError.new('already resolved') if @resolved

    @resolved = true
    if error.is_a?(StandardError)
      @value = error
    else
      @value = Rejection.new(error)
    end
    @notification&.signal(@value)

    nil
  end

  def resolved?
    @resolved
  end

  def fulfilled?
    @resolved && @fulfilled
  end

  def rejected?
    @resolved && !@fulfilled
  end

  def value!
    result = wait_for_value
    if result.is_a?(StandardError)
      raise result
    else
      result
    end
  end

  private def wait_for_value
    return @value if @resolved

    @notification = Async::Condition.new
    @notification.wait
  end

  private def force_stop
    return if @resolved

    @resolved = true
    @value = Cancel.new
    @notification&.signal(@value)

    nil
  end
end

require 'async/condition'

class Future
  def initialize(&block)
    raise ArgumentError.new('block must be given') unless block

    @task = Async(&block)
  end

  def resolved?
    %i(complete stopped failed).include?(@task.status)
  end

  def fulfilled?
    @task.status == :complete
  end

  def rejected?
    %i(stopped failed).include?(@task.status)
  end

  def value!
    result = @task.result
    if @force_stopped
      raise Cancel.new
    else
      result
    end
  end

  class Cancel < StandardError ; end

  # internal use only
  private def force_stop
    return if resolved?

    @force_stopped = true
    @task.stop
  end
end

class SimpleAwaitAll
  def initialize(*promises_or_futures)
    @items = promises_or_futures
  end

  def value!
    @items.map(&:value!)
  end
end

class AwaitAll
  def initialize(*promises_or_futures)
    @promise = Promise.new
    @promises_or_futures = promises_or_futures
    @tasks = promises_or_futures.map do |item|
      Async do
        begin
          item.value!
        rescue Promise::Cancel, Future::Cancel
          # pass
        rescue => err
          reject(err)
        end
      end
    end
    Async { fulfill(@tasks.map(&:result)) }
  end

  private def fulfill(results)
    return if @promise.resolved?

    @promise.fulfill(results)
  end

  private def reject(error)
    return if @promise.resolved?

    @promises_or_futures.each do |promise_or_future|
      promise_or_future.send(:force_stop)
    end
    @promise.reject(error)
  end

  def resolved?
    @promise.resolved?
  end

  def fulfilled?
    @promise.fulfilled?
  end

  def rejected?
    @promise.rejected?
  end

  def value!
    @promise.value!
  end

  private def force_stop
    @promises_or_futures.each do |promise_or_future|
      promise_or_future.send(:force_stop)
    end
    @promise.send(:force_stop)
  end
end

class AwaitAny
  def initialize(*promises_or_futures)
    @promise = Promise.new
    @promises_or_futures = promises_or_futures
    promises_or_futures.each do |item|
      Async do
        begin
          fulfill(item.value!)
        rescue Promise::Cancel, Future::Cancel
          # pass
        rescue => err
          reject(err)
        end
      end
    end
  end

  private def fulfill(result)
    return if @promise.resolved?

    @promises_or_futures.each do |promise_or_future|
      promise_or_future.send(:force_stop)
    end
    @promise.fulfill(result)
  end

  private def reject(error)
    return if @promise.resolved?

    @promises_or_futures.each do |promise_or_future|
      promise_or_future.send(:force_stop)
    end
    @promise.reject(error)
  end

  def resolved?
    @promise.resolved?
  end

  def fulfilled?
    @promise.fulfilled?
  end

  def rejected?
    @promise.rejected?
  end

  def value!
    @promise.value!
  end

  private def force_stop
    @promises_or_futures.each do |promise_or_future|
      promise_or_future.send(:force_stop)
    end
    @promise.send(:force_stop)
  end
end
