# Concept

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

## Sample run

```ruby
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
```