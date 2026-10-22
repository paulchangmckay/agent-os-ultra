# Chapter 12: Unit Testing

## Core Idea
A unit test's value is measured by its maintainability — write tests so that they never need to change unless the requirements of the system under test change, and so that failures are immediately clear about what broke and why.

## Frameworks Introduced
- **Unchanging Tests**: the ideal test never needs modification after it's written, unless the system's requirements change. Map every production change to an expected test-update outcome:
  - Pure refactorings → tests shouldn't change (a test that breaks here signals either a real behavior change or a test written at the wrong abstraction level).
  - New features → existing tests shouldn't change; only new tests get added.
  - Bug fixes → existing tests shouldn't change; add the missing case that would've caught the bug.
  - Behavior changes → the only case where updating existing tests is expected, because you're breaking an explicit contract.
  - When to use: as a diagnostic — if a test needed to change for a refactor/feature/bugfix, something is wrong with either the change or the test.
- **Test via Public APIs ("front door first")**: write tests that call the system the same way real users would — its public API — not private implementation details.
  - How: never strip `private` modifiers to test internals directly; test observable behavior/state reachable through the public surface.
- **State Testing vs. Interaction Testing**: state testing observes what the system looks like after invocation; interaction testing checks what calls it made to collaborators.
  - When to use: prefer state testing — it's less brittle because it doesn't care how the system arrived at its result, only what the result is.
- **DAMP, not DRY** ("Descriptive And Meaningful Phrases"): test code should tolerate more duplication than production code if that duplication makes the test clearer.
  - When to use: whenever DRY-style consolidation (shared constants, generic setup, generic validation helpers) would force a reader to jump between files to understand a single test.

## Key Concepts
- **Maintainable test**: one that "just works" — after writing it, engineers don't think about it again until it fails for a real reason.
- **Brittle test**: fails in response to an unrelated, non-buggy change to production code.
- **Clear test**: its purpose and cause of failure are immediately obvious to a diagnosing engineer; "trivially correct upon inspection."
- **Behavior** (vs. method): "any guarantee a system makes about how it will respond to a series of inputs while in a particular state," expressible as given/when/then. The method-to-behavior mapping is many-to-many.
- **Complete test**: contains all information the reader needs to understand how it arrives at its result.
- **Concise test**: contains no distracting or irrelevant information.
- **Test infrastructure**: shared code used across multiple test suites/classes; must be treated like production code, including having its own tests.
- **Change-detector test** (informal Google term, introduced fully in Ch 13): a test that fails on any implementation change regardless of behavior change — the failure mode of interaction-test overuse.

## Mental Models
- Use "given/when/then" (or "arrange/act/assert") as the default skeleton for any nontrivial test — it lets a reader parse a test at three granularities: name, structured comments, and code.
- Think of a test's name as its primary failure-report communication channel — start with "should" and read it as a sentence with the class name: `BankAccount should not allow withdrawals when balance is empty`.
- Treat logic in test code (loops, conditionals, string concatenation) as a red flag — tests can't be tested themselves, so any computed value hides a place a bug in the test could go unnoticed.
- Treat a test needing a validate-everything helper method as a signal the test isn't behavior-driven — general-purpose validation methods make bugs harder to localize because unrelated tests all fail together.

## Anti-patterns
- **Testing implementation details / private methods**: makes tests brittle to any refactor, even ones invisible to real users.
- **Method-oriented tests**: one test method per production method accumulates unrelated assertions as the method grows, producing convoluted, hard-to-reason-about tests.
- **Interaction tests over state tests**: coupling a test to *how* a result was produced rather than *what* the result is; breaks on refactors that preserve behavior, and can pass even when the real behavior is wrong (e.g., a record written then silently deleted).
- **Logic in tests**: even simple string concatenation can hide the exact bug the test should have caught; prefer literal, spelled-out values.
- **Overly DRY test helpers**: hiding key setup/assertion details behind generic helper methods (`createUsers`, `validateForumAndUsers`) makes tests concise but incomplete — readers can't verify correctness without leaving the test body.
- **Hardcoded, ambiguous shared constants**: `ACCOUNT_1`, `ACCOUNT_2` used across hundreds of lines of tests force readers to scroll to confirm relevance; prefer per-test builder/helper construction with sensible defaults.

## Code Examples
```java
// Brittle: tests private implementation details directly
@Test
public void emptyAccountShouldNotBeValid() {
  assertThat(processor.isValid(newTransaction().setSender(EMPTY_ACCOUNT))).isFalse();
}
```
```java
// Robust: tests only the public API
@Test
public void shouldNotPerformInvalidTransactions() {
  processor.setAccountBalance("me", 50);
  processor.setAccountBalance("you", 20);
  processor.processTransaction(newTransaction()
      .setSender("me").setRecipient("you").setAmount(100));
  assertThat(processor.getAccountBalance("me")).isEqualTo(50);
  assertThat(processor.getAccountBalance("you")).isEqualTo(20);
}
```
- **What it demonstrates**: the "front door first" principle — the second test achieves the same coverage without depending on the transaction processor's internal method structure.

```java
// Behavior-driven, given/when/then structure
@Test
public void transferFundsShouldMoveMoneyBetweenAccounts() {
  // Given two accounts with initial balances of $150 and $20
  Account account1 = newAccountWithBalance(usd(150));
  Account account2 = newAccountWithBalance(usd(20));
  // When transferring $100 from the first to the second account
  bank.transferFunds(account1, account2, usd(100));
  // Then the new account balances should reflect the transfer
  assertThat(account1.getBalance()).isEqualTo(usd(50));
  assertThat(account2.getBalance()).isEqualTo(usd(120));
}
```
- **What it demonstrates**: explicit given/when/then structuring, readable at three levels (name, comments, code).

## Reference Tables

| Change type | Should existing tests change? | Why |
|---|---|---|
| Pure refactoring | No | Tests verify behavior is preserved, not implementation |
| New feature | No (only add new tests) | Existing behaviors are unaffected |
| Bug fix | No (only add the missing case) | The bug indicates a missing test case, not a wrong existing one |
| Behavior change | Yes | You're intentionally breaking an explicit contract |

| Verification style | Checks | Brittleness | Prefer when |
|---|---|---|---|
| State testing | What the system looks like after invocation | Low | Default choice |
| Interaction testing | What calls were made to collaborators | High | Only when state testing is infeasible (see Ch 13) |

## Worked Example
Consider `displayTransactionResults(User user, Transaction transaction)`, which shows a purchase message and, conditionally, a low-balance warning. A naive method-oriented test (`testDisplayTransactionResults`) grows over time to assert both messages in a single test body, becoming harder to reason about as more conditions are added. Rewritten as behavior-driven tests, it splits into `displayTransactionResults_showsItemName` (asserts only the purchase message) and `displayTransactionResults_showsLowBalanceWarning` (sets up a low-balance user and asserts only the warning). Each test now maps to exactly one "given/when/then" guarantee, its name alone documents the behavior under test, and a failure immediately identifies which guarantee broke — without requiring the reader to mentally separate two concerns bundled into one method-shaped test.

## Key Takeaways
1. Strive for unchanging tests: only a real behavior-contract change should require touching an existing test.
2. Test via public APIs — if a test would break a real user when it breaks, it's testing the right layer.
3. Prefer state testing over interaction testing by default.
4. Write one test per behavior, not one test per method; name tests after the behavior, ideally readable as "ClassName should X when Y."
5. Keep tests free of logic (loops/conditionals/computed values) — tests must be correct on inspection since they have no tests of their own.
6. Favor DAMP over DRY in test code: some duplication is a fair price for a test that's understandable without leaving its own body.
7. Write clear failure messages that state expected vs. actual explicitly; prefer assertion libraries (e.g., Truth) that surface real values over generic booleans.

## Connects To
- **Ch 11 (Testing Overview)**: unit tests are the base of the test pyramid this chapter builds maintainability guidance on top of.
- **Ch 13 (Test Doubles)**: the state-vs-interaction testing discussion here is expanded into full guidance on mocking frameworks and when to avoid them.
- **Ch 9 (Code Review)**: reviewers rely on test clarity and completeness to verify correctness without manually tracing logic.
- **Ch 22 (Large-Scale Changes)**: Google's reliance on LSCs for pure refactorings is exactly the case the "unchanging tests" framework is designed to protect.
