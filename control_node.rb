class ControlNode
  attr_reader :result, :state

  def initialize
    yield(method(:resolve), method(:reject))
  end

  def chain(on_success, on_failure=nil)
    raise "ControlNode#chain requires a success branch" unless on_success

    if @state == :succeeded
      chain = on_success.call(result)
      return chain.to_deferrable if chain.respond_to?(:to_deferrable)
      ControlNode.new { |res,_| res.call(result) }
    else
      chain = on_failure.call(result) if on_failure
      return chain.to_promise if chain.respond_to?(:to_promise)
      VoidControlNode.new(result)
    end
  end

  def to_promise
    self
  end
  
  private

  def resolve(val)
    @state = :succeeded
    @result = val
  end

  def reject(val)
    @state = :failed
    @result = val
  end

  class VoidNode
    attr_reader :result, :state

    def initialize(result)
      @result = result
      @state = :failed # implicitly
    end

    def to_promise
      self
    end

    def chain(_,_=nil)
      self
    end
  end
end
