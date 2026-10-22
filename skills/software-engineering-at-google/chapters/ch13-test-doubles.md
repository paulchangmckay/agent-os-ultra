# Chapter 13: Test Doubles

## Core Idea
Prefer real implementations over test doubles whenever they're fast, deterministic, and easy to construct; when a double is needed, prefer a fake over stubbing, and prefer stubbing over interaction testing — each step down that ladder trades fidelity and clarity for convenience.

## Frameworks Introduced
- **The Test Double Preference Ladder**: real implementation → fake → stubbing → interaction testing (mocking), in decreasing order of preference.
  - When to use: default to the leftmost option that's actually feasible; only move right when execution time, determinism, or dependency-construction cost rules out the option to its left.
- **Classical testing vs. mockist testing**: classical testing prefers real implementations of dependencies; mockist testing prefers mocking frameworks by default.
  - Google's stance: classical testing scales better; mockist testing requires strict upfront design discipline that doesn't hold at scale, and Google's default engineering habits favor classical anyway.
- **Fidelity**: how closely a test double's behavior matches the real implementation's behavior, from the perspective of the test (not necessarily perfect fidelity in every dimension, e.g. latency or storage medium).
  - How: a fake must conform to the real implementation's API contract — same output and state changes for the same input — even if internal details (in-memory vs. disk) differ.
- **@DoNotMock** (Java/ErrorProne static analysis annotation): lets an API owner declare "don't mock this type, use the real implementation or an official fake instead."
  - When to use: for value objects simple enough to use as-is, and for APIs with well-engineered fakes — protects the API owner's ability to change their implementation without invalidating thousands of mock-based assumptions.

## Key Concepts
- **Test double**: any object/function that stands in for a real implementation in a test (the umbrella term; "mocking" is avoided as ambiguous shorthand).
- **Seam**: a point in code that allows a test double to be substituted for a real dependency — most commonly created via dependency injection.
- **Fake**: a lightweight, working implementation of an API that behaves like the real thing but isn't production-suitable (e.g., an in-memory database).
- **Stub**: hardcoded, inline behavior given to an otherwise-behaviorless function (`when(...).thenReturn(...)`).
- **Mock** (as created by a mocking framework): a test double whose behavior/expected calls are specified inline in the test, used for stubbing and/or interaction testing.
- **Interaction testing**: validating that a function was called correctly (arguments, call count) without invoking its real implementation.
- **State-changing vs. non-state-changing functions**: state-changing functions have side effects on the world (`sendEmail()`, `saveRecord()`); non-state-changing functions only return information (`getUser()`, `findResults()`). Interaction testing is appropriate mainly for the former.
- **Change-detector test**: Google's jokey internal term for a test so overloaded with interaction assertions that it fails on any implementation change, even behavior-preserving ones.

## Mental Models
- Think of real dependencies as giving "realism," while test doubles buy "isolation" — Google explicitly prefers realism, because isolating the system under test from real dependencies means bugs in those dependencies won't surface until later (integration or production).
- Treat a fake as an *optimization*: you pay upfront cost to write and maintain it in exchange for faster, cheaper tests later; if that trade doesn't pay off (few users, low real-implementation cost), just use the real thing.
- When deciding real vs. double, weigh three factors together, not independently: execution time, determinism, and dependency-construction cost — a real implementation can be fine on two axes and unusable on the third (e.g., fast and deterministic but has an unconstructable dependency tree).
- Stubbing should have a "direct relationship with the test's assertions" — if you're stubbing a function just to get past setup rather than to drive the specific behavior under test, that's a smell.

## Anti-patterns
- **Overusing mocking frameworks**: Google's own history — early enthusiasm for mocking frameworks led to tests that were "easy to write" but "required constant effort to maintain while rarely finding bugs," prompting some engineers to declare "no more mocks!"
- **Stubbing as a catch-all**: leaks implementation details into tests (brittle to refactors), can't guarantee the stubbed contract is actually correct, and can't store state (can't verify a `save()` via a subsequent `get()`).
- **Over-reliance on interaction testing**: produces "change-detector tests" that fail on any implementation change regardless of whether real behavior changed; also can't tell you the system actually *works*, only that a function was *called*.
- **Interaction testing non-state-changing calls**: redundant (the return value is already exercised elsewhere) and brittle (any change to call pattern breaks the test without a real bug).
- **Overspecified interaction tests**: asserting every argument to every call in one test (e.g., `verify(userPrompt).setText("Fake User", "Good morning!", "Version 2.1")`) makes the test fail on unrelated changes; assert only the argument relevant to the specific behavior under test (`eq("Fake User"), any(), any()`).
- **Unfaithful mocks going stale** (bridges to Ch 14): a mock's assumed behavior is defined by the test author, not the real implementation's owner — when the real thing changes, there's no signal that the mock (and the test) is now wrong.

## Code Examples
```java
// A trivial fake
class TestDoubleCreditCardService implements CreditCardService {
  @Override
  public boolean chargeCreditCard(CreditCard creditCard, Money amount) {
    return true;
  }
}
```
- **What it demonstrates**: even a minimal test double is enough to validate logic (e.g., the expired-card branch) that doesn't depend on the double's own behavior.

```java
// Dependency injection creates a seam
class PaymentProcessor {
  private CreditCardService creditCardService;
  PaymentProcessor(CreditCardService creditCardService) {
    this.creditCardService = creditCardService;
  }
  ...
}
```
- **What it demonstrates**: passing dependencies in (rather than constructing them internally) is what makes substituting a test double possible at all.

```java
// Overuse of stubbing — brittle, exposes implementation details
when(mockCreditCardServer.isServerAvailable()).thenReturn(true);
when(mockTransactionProcessor.beginTransaction()).thenReturn(transaction);
when(mockCreditCardServer.initTransaction(transaction)).thenReturn(true);
when(mockCreditCardServer.pay(transaction, creditCard, 500)).thenReturn(false);
when(mockTransactionProcessor.endTransaction()).thenReturn(true);
paymentProcessor.processPayment(creditCard, Money.dollars(500));
verify(mockCreditCardServer).pay(transaction, creditCard, 500);
```
```java
// Refactored using a fake/real credit card server — shorter, hides no implementation details
paymentProcessor = new PaymentProcessor(creditCardServer, transactionProcessor);
paymentProcessor.processPayment(creditCard, Money.dollars(500));
assertThat(creditCardServer.getMostRecentCharge(creditCard)).isEqualTo(500);
```
- **What it demonstrates**: the same test coverage achieved with far less stubbing boilerplate and no leaked implementation details, once a fake/real server is available.

## Reference Tables

| Technique | Fidelity | Boilerplate | Brittleness | Best for |
|---|---|---|---|---|
| Real implementation | Highest | None (if constructible) | Lowest | Value objects, fast/deterministic dependencies |
| Fake | High (API-contract level) | Written once by the API owner | Low | Anything with an available, maintained fake |
| Stubbing | Author-defined, unverified | Per-test, moderate | Medium-High | Forcing a specific return value/state into the SUT |
| Interaction testing (mocking) | N/A (doesn't verify state) | Per-test, high if overused | Highest | State-changing calls where state testing is infeasible, or verifying call counts |

| Decision factor | Favors real implementation | Favors test double |
|---|---|---|
| Execution time | Adds ~1ms/test | Adds seconds per test, especially at hundreds of test cases |
| Determinism | Hermetic, single-threaded | Multithreaded, relies on external services, system clock |
| Dependency construction | Simple object graph | Deep/complex dependency tree, e.g. `new Foo(new A(new B(new C()), new D()), ...)` |

## Worked Example
An ecommerce `PaymentProcessor.makePayment()` depends on a `CreditCardService`. Using a real credit card service in tests is infeasible (real transaction fees, network calls). A trivial fake (`TestDoubleCreditCardService.chargeCreditCard()` always returns `true`) is enough to validate the expired-card branch, since that code path never reaches the credit card service at all. For the "charge succeeds/fails" branches, the chapter shows the progression: an overspecified stub-and-interaction-test version (five `when(...)` stubs plus a final `verify()`, unable to actually confirm the charge happened) versus a refactored version using a real/fake `creditCardServer` that lets the test simply call `processPayment()` and then assert against the server's own state (`getMostRecentCharge()`). The second version is shorter, doesn't leak the transaction processor's internal call sequence into the test, and actually verifies the payment took effect — illustrating state testing over interaction testing and fakes over stubbing in one example.

## Key Takeaways
1. Prefer a real implementation first; move to a test double only when execution time, determinism, or dependency-construction cost makes the real thing infeasible.
2. When a double is needed, prefer a fake (written and maintained by the API's owning team) over stubbing or mocking.
3. Fakes need their own tests (often contract tests run against both the fake and the real implementation) so their fidelity doesn't silently drift.
4. Constrain stubbing to a small number of functions with a direct relationship to the test's assertions — heavy stubbing signals overuse or an overly complex system under test.
5. Reserve interaction testing for state-changing functions, and only when state testing genuinely isn't possible; avoid it for non-state-changing (read-only) calls.
6. Avoid overspecifying interaction tests — assert only the arguments relevant to the behavior under test, using matchers like `any()` for the rest.
7. Watch for @DoNotMock-style signals: if an API is being mocked broadly with assumptions the owning team never validated, that's a maintenance and correctness risk for everyone.

## Connects To
- **Ch 11 (Testing Overview)**: this chapter is the deep dive behind the "no more mocks!" mention there.
- **Ch 12 (Unit Testing)**: directly extends the state-testing-vs-interaction-testing framework introduced there.
- **Ch 14 (Larger Testing)**: picks up where this chapter leaves off — "unfaithful doubles" is listed there as a specific coverage gap that larger tests must address.
- **Ch 18 (Build Systems and Build Philosophy)**: Bazel's build caching is referenced as mitigating the increased build time from using real implementations and their dependencies.
