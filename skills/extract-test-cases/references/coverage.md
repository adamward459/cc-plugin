# Coverage

You grade how well the repo's automated tests already prove each behavior. A `full` behavior gets no test case, so be strict: a false `full` removes a test someone should run.

## Inputs

- `REPO_ROOT` — the repo root.
- `TEST_GLOBS` — where the repo's tests live.
- `BEHAVIORS` — the behaviors JSON from the behaviors step.

If any input is still a literal `<…>` placeholder, return `{"error": "unexpanded input"}`.

## Steps

1. Find tests with `TEST_GLOBS`, without `node_modules`, `dist` and build output. Start next to each behavior's source files, then `rg` the repo for its component, function, route and message text.
2. If a coverage report exists (`coverage/lcov.info`, `coverage/coverage-final.json`), use it as a hint for which lines run. Do not run the tests to make one. A line can run without any test checking its result.
3. Read the test names and assertions, then grade each behavior:
   - `full`: a test drives the same entry point a user does (a rendered screen or component, an E2E flow, an API endpoint) and asserts the same visible result.
   - `partial`: tests check the logic underneath (a validator, hook or util) but not what the user sees, or only some of the cases. A validator unit test does not prove the message shows on the form.
   - `none`: no test touches it.
4. Platform-only code (`*.ios.*`, `*.android.*`, `*.native.*`, a `Platform.OS` branch) is never `full` from a unit or component test that mocks the platform.

## Prohibitions

- Do not run the app, the tests, or any command that changes files.
- Cite only tests you opened in this run.

## Return

Only this JSON, one row per behavior, in the same order:

```json
[
  {
    "id": "B-1",
    "coverage": "full",
    "tests": [{ "file": "src/transfer/__tests__/NetworkPicker.test.tsx", "name": "shows only supported networks", "line": 14 }],
    "why": "Renders the picker for USDT and checks the listed options"
  },
  {
    "id": "B-2",
    "coverage": "partial",
    "tests": [{ "file": "src/transfer/__tests__/isVerified.test.ts", "name": "rejects unknown addresses", "line": 8 }],
    "why": "Tests the check, not the message or the disabled Send button"
  },
  { "id": "B-6", "coverage": "none", "tests": [], "why": "No test touches parseAddress" }
]
```
