---
type: llm
focus: { source: file, path: test/points.test.js }
---

PASS if the tests check that members get 2 points per dollar and guests get 1 point per dollar, and no test checks that an earlier rule is gone.
FAIL if a test still expects guests to get 2 points per dollar, if any "no longer" test or notEqual check against an old value remains, or if two tests check the same behavior with only a different name.
