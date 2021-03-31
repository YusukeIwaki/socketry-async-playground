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
    @notification&.signal(value)

    nil
  end

  class Rejection < StandardError ; end

  def reject(error)
    raise ArgumentError.new('already resolved') if @resolved

    @resolved = true
    if error.is_a?(StandardError)
      @value = error
    else
      @value = Rejection.new(error)
    end

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
    @task.result
  end
end
