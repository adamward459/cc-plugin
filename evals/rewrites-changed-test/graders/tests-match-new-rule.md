---
type: llm
focus: { source: file, path: test/shipping.test.js }
---

PASS if the tests check that an order over $50 ships free and an order of $50 or less pays $5, and no test checks that the old behavior is gone.
FAIL if a test still expects $5 on an order over $50, if a test is framed around the old flat fee, such as a "no longer" title or a notEqual check against the old value, or if two tests check the same behavior with only a different name.
