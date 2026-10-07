---
type: llm
focus: { source: file, path: test/profile.test.js }
---

PASS if some test fails when the public profile includes the email address. An exact deepEqual on an object without email counts, and so does an explicit check that email is missing.
FAIL if no test would fail when email comes back into the public profile, or if a test still expects email to be present.
