---
name: update-tests
description: Updates existing tests when a feature's behavior changes, so the suite describes only the current behavior. Rewrites or deletes tests for the old behavior instead of adding tests that check the old behavior is gone. Use when changing, replacing, or removing existing behavior that already has tests, or when a test suite has grown "no longer does X" tests.
---

# Update tests

Tests describe what the code does now. They are not a history of what it used to do.

## The failure this skill prevents

1. Feature A becomes A'. The tests for A are updated to A'. Good.
2. A' becomes A''. The tests for A' stay. New tests check that A' behavior "no longer" happens, and more tests cover A''.

After step 2 the suite carries dead weight. A test like "does not apply the 15% discount" passes for almost any code, so it proves nothing. It also blocks a later change back toward A', for no real reason.

The fix: treat the old tests as code you are changing, not as code you must protect.

## Workflow

Copy this checklist and track it:

```
- [ ] 1. Find every test that covers the behavior you are changing
- [ ] 2. Sort each one: keep, rewrite, or delete
- [ ] 3. Apply the sort, then add tests only for gaps
- [ ] 4. Scan the diff for "absence" tests
- [ ] 5. Report removed and rewritten tests
```

### 1. Find the tests

Before you write any test, search for the ones that already touch the change. Search for:

- the function, component, or endpoint name
- old literal values (the old rate, the old message text, the old field name)
- test titles that describe the old behavior

Read these tests. Do not only read the ones that fail. A test can still pass and still describe behavior that no longer matters.

### 2. Sort each test

| The test checks...                           | Action                                               |
| -------------------------------------------- | ---------------------------------------------------- |
| behavior that is still true                  | Keep it as is.                                       |
| behavior that changed                        | Rewrite it in place to check the new behavior. Keep the same place in the file, and fix the title. |
| behavior that no longer exists               | Delete it.                                           |
| that the old behavior is absent (from an earlier change) | Delete it, unless an exception below applies. |

Rewrite in place before you add a new test. One test per behavior is the goal.

### 3. Add tests only for gaps

After the rewrite, check what new behavior has no test yet. Add tests for that, and only that.

### 4. Scan for absence tests

Look at every test you added or changed. Flag it if it:

- has a title with "no longer", "anymore", "still", "not ... old", "legacy", "previously", or "instead of"
- asserts that a removed field, prop, flag, or call is `undefined`, missing, or not called
- only makes sense to someone who knows an earlier version of the code

For each flagged test, ask: "If the old behavior came back, would anyone care?" If the answer is no, delete the test.

### 5. Report

In your summary, list the tests you deleted and the tests you rewrote, with one short reason each. Deleting tests is a real change, and the user should see it.

## When an absence test is correct

Keep or add a test that checks something is gone only when the absence is itself a requirement:

- **Security or privacy**: a removed field must not leak in the API response, or an old endpoint must now reject requests.
- **A real bug fix**: the old behavior was a bug, and a regression test stops it from coming back.
- **A public contract**: users or other services depend on the old behavior being removed, for example a deprecated flag that must now fail loudly.

Name these tests for the requirement, not for the history. Write "rejects requests without a token", not "no longer allows anonymous access".

## Example

A discount rule changes three times:

- A: 10% off all orders
- A': 15% off all orders
- A'': 15% off orders over $100, 0% otherwise

**Bad** (after the A'' change):

```ts
it("applies 15% discount", ...)                     // left from A'; now wrong for small orders, so someone adds a guard
it("does not apply 10% discount anymore", ...)      // left from A'
it("no longer discounts every order", ...)          // new absence test
it("applies 15% discount over $100", ...)
it("applies no discount at $100 or less", ...)
```

**Good**:

```ts
it("applies 15% discount to orders over $100", ...)  // rewritten from "applies 15% discount"
it("applies no discount to orders of $100 or less", ...)
```

The 10% test is deleted. The "no longer" test is never written. The edge at exactly $100 is covered once, by the second test.
