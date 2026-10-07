---
name: extract-test-cases
description: Turns a requirement (ticket text, spec, or notes) and a branch into a committed case file, specs/testcases/<TICKET>.md. It lists every behavior with its requirement and code sources, checks which ones the repo's automated tests (unit, component, E2E) already prove, and writes test cases for the rest. Use when the user asks what to test, wants test cases, QA scenarios or a manual test plan for a ticket or branch, or wants evidence recorded for a feature that has no case file yet.
argument-hint: "[<ticket or requirement>] [--base <ref>]"
---

# Extract Test Cases

Reads the requirement and the code for a feature and writes `specs/testcases/<KEY>.md`: every behavior, how well automated tests already prove it, and test cases for the rest. It only writes this file. It never runs the app and never records.

## Invariants

1. **Never duplicate a test.** A behavior is `full` only when a test drives the same entry point a user does (a rendered screen or component, an E2E flow, an API endpoint) and asserts the same visible result. A unit test of a validator, hook or util is `partial`. Every `full` behavior gets no case; every other behavior is covered by a case.
2. **Every `full` row cites a real test**: file and test name, found with `rg` in this run.
3. **Every expected result comes from the requirement or the user**, never from the code's current output. A test copied from the code can only pass.
4. **Ask before writing.** When the requirement and the code disagree, the code looks wrong for the user, or a setup value is missing, ask the user and wait. A guessed expected result is wrong in every recording made from it.
5. **IDs are stable.** Keep every existing `TC-n` and `B-n`. New ones take the next free number. Never renumber or delete: recordings and MR comments point to the IDs.
6. **The file says what to check, not who checks it.** Never label a case manual, automated, agent or human.
7. **No secrets.** The file is committed. Name the account or where the secret lives.
8. **Never commit.**

## Phases

Each phase ends with a gate. A failed gate stops the run and says which gate failed.

| #   | Phase     | Runs in      | Loads                     | Produces                    |
| --- | --------- | ------------ | ------------------------- | --------------------------- |
| 1   | Sources   | main         | —                         | key, inputs, repo facts     |
| 2   | Behaviors | **subagent** | `references/behaviors.md` | behaviors JSON              |
| 3   | Coverage  | **subagent** | `references/coverage.md`  | one row per behavior        |
| 4   | Ask       | main         | —                         | the user's answers          |
| 5   | Write     | main         | —                         | the case file and a report  |

Phases 2 and 3 read a lot of code, so they run in subagents and return short JSON. If you cannot spawn subagents, follow the two reference files yourself.

### Phase 1 — Sources `[main]`

- **Key:** the ticket ID from the user's message or the branch name (`feat/transfer/AO-439-crypto-transfer` → `AO-439`). Without one, the branch name with `/` replaced by `-`.
- **Requirement:** the text the user gave (pasted, a file, or a ticket they already fetched), verbatim. This skill does not fetch tickets.
- **Base:** `--base`, else the branch the user names, else the target branch named in project docs (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`), else the default branch from `git symbolic-ref refs/remotes/origin/HEAD`, else the only one of `main`, `master`, `develop`, `dev`, `DEV` that exists. If several fit, ask. A wrong base gives a wrong diff and nothing errors.
- **Existing file:** read `specs/testcases/<KEY>.md` if it exists. This run updates it.
- **Repo facts:** how tests are found (the `testMatch` or `include` of a Jest, Vitest, Playwright, Cypress, Detox or Maestro config; else `**/__tests__/**`, `**/*.test.*`, `**/*.spec.*`), and any platform-only code (`*.ios.*`, `*.android.*`, `*.native.*`, `Platform.OS` branches). Pass them to phase 3 as `TEST_GLOBS`.

**Gate:** a requirement or a non-empty diff against the base. With none, ask the user for one and stop.

### Phase 2 — Behaviors `[subagent]`

Dispatch one agent:

> Read `<SKILL_DIR>/references/behaviors.md` and follow it as your complete instructions.
> Inputs: `REPO_ROOT=<abs>`, `BASE=<ref>`, `REQUIREMENT=<text or none>`, `EXISTING_FILE=<abs path or none>`.
> Return only the JSON its Return section specifies.

Expand `<SKILL_DIR>` and every `<abs>` to a full path first. A subagent inherits no shell state.

**Gate:** valid JSON, at least one behavior, and every behavior has `sources` with at least one `path:line`.

### Phase 3 — Coverage `[subagent]`

Dispatch one agent:

> Read `<SKILL_DIR>/references/coverage.md` and follow it as your complete instructions.
> Inputs: `REPO_ROOT=<abs>`, `TEST_GLOBS=<from phase 1>`, `BEHAVIORS=<phase 2 behaviors JSON>`.
> Return only the JSON its Return section specifies.

**Gate:** check every `full` row yourself: `rg -F "<test name>" "<file>"` must match. When the name is built at run time (`it.each`, a template string), check that line `<line>` of the file is that `it(` or `test(` call. A row that does not match becomes `partial` when another test touches the logic, else `none`.

### Phase 4 — Ask `[main]`

Take the `ask_user` items from phase 2 and every setup value that is still `null`. Keep only what changes a case's steps, expected result or setup. Code issues that change no test go in the report.

Ask everything in one numbered message: what the requirement says, what the code does (`path:line`), and your suggested answer. Wait for the answers.

- An answer becomes the expected result and a source `Answer "<short quote>"`.
- If the user does not know, the behavior gets no case and `unclear` in its Test column. A setup value nobody knows becomes a `TODO:` line.

Skip this phase when nothing is unclear.

### Phase 5 — Write `[main]`

1. On a re-run, match each behavior to an existing one by its sources and wording. Keep matched IDs.
2. Group behaviors into cases: one case may cover several behaviors when the same steps show them all. Aim for 3–12 cases; a long list of trivial cases hides the important ones.
3. Write the file in the format below.
4. Print the report and stop. The user reviews the file before anything records it.

```
Test cases: specs/testcases/AO-439.md
- 9 behaviors: 2 fully covered by automated tests, 7 need test cases
- 5 test cases (web 5)
- Inputs: AO-439 ticket text from the user, diff vs DEV
- Asked: 1 question (daily limit: 5 a day, from the user)
- Code issues seen: "Send" is not disabled while the request runs (`TransferForm.tsx:58`)
```

If `.gitignore` does not ignore `.evidence/*/TC-*/`, add a line to the report telling the user to add it. Do not edit `.gitignore`.

## Case file format

Tools read this file by these section and field names, so keep them stable.

```markdown
# AO-439 - Crypto transfer

Source: AO-439 ticket text from the user, diff `feat/transfer/AO-439-crypto-transfer` vs `DEV`

## Setup

- App: web DEV, http://localhost:3000/transfer
- Account: tier 2 user (QA account "tier2-trader" in 1Password)
- Data: at least 50 USDT, one verified and one unverified address book entry
- Flags: `NEXT_PUBLIC_TRANSFER_V2=true` in `.env.local`

## Behaviors

| ID  | Behavior | Sources | Coverage | Test |
| --- | -------- | ------- | -------- | ---- |
| B-1 | The network picker lists only networks the selected coin supports | AC-1; `src/transfer/NetworkPicker.tsx:18-30` | full: `NetworkPicker.test.tsx` › "shows only supported networks" | — |
| B-2 | A transfer to an unverified address shows "Verify this address first" and blocks Send | AC-2; `src/transfer/TransferForm.tsx:44` | partial: `isVerified.test.ts` checks the rule, not the screen | TC-1 |
| B-6 | A pasted address with spaces is trimmed before it is checked | `src/transfer/parseAddress.ts:3` | none | TC-2 |

## Test Cases

### TC-1 - Unverified address blocks the transfer

- Behaviors: B-2
- Platform: web
- Preconditions: on the transfer form, USDT on TRON selected
- Steps:
  1. Pick the unverified address from the address book
  2. Enter `10` in "Amount"
- Expected: "Verify this address first" shows under the address. "Send" is disabled.
```

Rules for the fields:

- **Setup** lists only what every case needs. Leave out a line that does not apply.
- **Sources:** `AC-N`, `Req "<quote>"`, `Answer "<quote>"` or `path:line`. Use `AC-N` only when the requirement itself numbers the rule that way; a code-only behavior numbered as an AC looks like something the requirement asked for.
- **Platform:** `web`, `ios`, `android`, or `ios, android` when the same steps work on both. A `.ios.tsx` or `.android.tsx` file, or a `Platform.OS` branch, limits it to that platform.
- **Steps:** short, in order, with real labels and values from the code (`Tap "Send"`, `Enter 0.000001`).
- **Expected:** text or an element that appears or disappears, so a recording can show it.
- **Preconditions:** optional, only when a case needs more than Setup.

On a re-run, cases that were already recorded have `Mode`, `Status`, `Recording` and `Note` lines. They are history. A case with one platform has them as plain lines. A case with several platforms has one block per platform, because each platform passes or fails on its own:

```markdown
- Platform: ios, android
- Steps: ...
- Expected: ...
- ios:
  - Mode: agent
  - Status: pass
  - Recording: TC-4/TC-4-ios.mp4
  - Note: Lockout text showed 15:00 and counted down.
- android:
  - Mode: agent
  - Status: fail
  - Recording: TC-4/TC-4-android.mp4
  - Note: Resend button stayed visible under the lockout text.
```

- A case whose steps or expected result change gets one line `- Outdated: <what changed>`, and every `Status` in it becomes `outdated`. Keep every `Mode`, `Recording` and `Note` line as it is.
- A platform added to a recorded case: move the plain result lines into a block for the old platform. The new platform gets no block; the recording adds it.
- A platform dropped from a case: keep its block and add `- Removed: <reason>` inside it.
- Leave unchanged cases alone.
- A case that is no longer valid gets `- Removed: <reason>`.
- A file without a Behaviors table gets one, and each case gets a `- Behaviors:` line.
