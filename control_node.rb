=begin

We want the ability to compose a set of actions that may or may not take effect,
dependent on appropriate predicates, and to track the result of this at each
stage. In general, we want the default outcome of failure to be chain
termination; this is technically overridable, but this implementation does not
handle that in the fluent API at this point.

The approach here is fairly straightforward; the treatment of failure is closer
to composition of Either in Haskell than the Javascript Promise API from which
this approach derives. There is no particular fundamental reason for this -- I
simply have no experience using the Promise API in anger, and generally find
post-error computation error-prone (it seems typically correct in its initial
incarnations, but incremental changes tend to endanger error conditions)

The design of this API does _not_ handle aynchronicity; it is a logic-management
tool. An obvious -- and hopefully imminent, definitely breaking -- alteration is
to allow the specification of `pending` conditional flow graphs, and thereby to
construct useful, cookie-cutter error-handling systems.

An earlier conceptual approach to this idea was more block-oriented (i.e. the
actions were specified within the context of the generated deferrable
object). Although this was appealing -- and presented an immediately-apparent
predicate system -- the need to evaluate deferred computation in the context of
the caller significantly complicated the actual implementation.

promise = ControlNode.new { |res, rej| res.call(5) }.
  chain(
    -> (val) { puts "5 = #{val}" },
    -> (_)   { fail "Not executed" }
  ).chain(
    -> (val) { puts "Fell through to second chain (5 is still #{val})"}
  ).chain(
    -> (val) { puts "Synthesising new (rejecting) promise"; ControlNode.new { |res, rej| rej.call(val) } }
  ).chain(
    -> (_)   { fail "Not executed -- but required by API (success should be expected!)" },
    -> (val) { puts "Which rejects with value #{val} (yet again)" }
  ).chain(
    -> (_)   { fail "Void deferrables do not resolve" },
    -> (_)   { fail "Nor do they reject" }
  )

puts "And finally we have a failing (and void) node with bound result of 5 (#{promise.result})"

=end

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
