---
name: extract-test-cases
description: Turns a requirement (ticket text, spec, or notes) and a branch into a committed case file in the project's test case folder (specs/testcases/<KEY>.md unless the project docs name another). It lists every behavior with its requirement and code sources, checks which ones the repo's automated tests (unit, component, E2E) already prove, and writes test cases for the rest, one collapsible table row per scenario, each marked for video or screenshot proof. Use when the user asks what to test, wants test cases, QA scenarios or a manual test plan for a ticket, feature or branch, or wants evidence recorded for a feature that has no case file yet.
argument-hint: "[<ticket or requirement>] [--base <ref>]"
---

# Extract Test Cases

Reads the requirement and the code for a feature and writes `<CASE_DIR>/<KEY>.md`: every behavior, how well automated tests already prove it, and test cases for the rest. It only writes this file. It never runs the app and never records.

## Invariants

1. **Never duplicate a test.** A behavior is `full` only when a test drives the same entry point a user does (a rendered screen or component, an E2E flow, an API endpoint) and asserts the same visible result. A unit test of a validator, hook or util is `partial`. Every `full` behavior gets no case; every other behavior is covered by a case.
2. **Every `full` row cites a real test**: file and test name, found with `rg` in this run.
3. **Every check comes from the requirement or the user**, never from the code's current output. A test copied from the code can only pass.
4. **Ask before writing.** When the requirement and the code disagree, the code looks wrong for the user, or a setup value is missing, ask the user and wait. A guessed check is wrong in every recording made from it.
5. **IDs are stable.** Keep every existing `TC-n` and `B-n`. New ones take the next free number. Never renumber or delete: recordings and PR comments point to the IDs.
6. **The file says what to check, not who checks it.** Never label a case manual, automated, agent or human.
7. **No secrets.** The file is committed. Name the account or where the secret lives.
8. **Never commit.**

## Phases

Each phase ends with a gate. A failed gate stops the run and says which gate failed.

| #   | Phase     | Runs in      | Loads                     | Produces                   |
| --- | --------- | ------------ | ------------------------- | -------------------------- |
| 1   | Sources   | main         | —                         | key, inputs, repo facts    |
| 2   | Behaviors | **subagent** | `references/behaviors.md` | behaviors JSON             |
| 3   | Coverage  | **subagent** | `references/coverage.md`  | one row per behavior       |
| 4   | Ask       | main         | —                         | the user's answers         |
| 5   | Write     | main         | —                         | the case file and a report |

Phases 2 and 3 read a lot of code, so they run in subagents and return short JSON. If you cannot spawn subagents, follow the two reference files yourself.

### Phase 1 — Sources `[main]`

- **Case folder (`CASE_DIR`):** the folder the project docs (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`) name for test case files, else `specs/testcases`.
- **Key:** when the project docs name case files by feature, the feature's name; reuse an existing file for the same feature, and ask when it is unclear which feature this is. Otherwise the ticket ID from the user's message or the branch name (`feat/transfer/AO-439-crypto-transfer` → `AO-439`). Without one, the branch name with `/` replaced by `-`.
- **Requirement:** the text the user gave (pasted, a file, or a ticket they already fetched), verbatim. This skill does not fetch tickets.
- **Base:** `--base`, else the branch the user names, else the target branch named in project docs, else the default branch from `git symbolic-ref refs/remotes/origin/HEAD`, else the only one of `main`, `master`, `develop`, `dev`, `DEV` that exists. If several fit, ask. A wrong base gives a wrong diff and nothing errors.
- **Existing file:** read `<CASE_DIR>/<KEY>.md` if it exists. This run updates it.
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

Take the `ask_user` items from phase 2 and every setup value that is still `null`. Keep only what changes a case's steps, checks or setup. Code issues that change no test go in the report.

Ask everything in one numbered message: what the requirement says, what the code does (`path:line`), and your suggested answer. Wait for the answers.

- An answer becomes a check and a source `Answer "<short quote>"`.
- If the user does not know, the behavior gets no case and `unclear` in its Test column. A setup value nobody knows becomes a `TODO:` line.

Skip this phase when nothing is unclear.

### Phase 5 — Write `[main]`

1. On a re-run, match each behavior to an existing one by its sources and wording. Keep matched IDs.
2. Group behaviors into cases. **One case is one scenario**: a path a user takes from a start state to an end state. Each thing to verify along that path is a numbered check inside the case, not a case of its own. Aim for 3–12 cases; a long list of trivial cases hides the important ones.
3. Mark one case ★: the happy path, the main success flow of the feature from start to end. It is the demo a reviewer watches first.
4. Choose each case's proof (see "Proof" below).
5. Write the file in the format below.
6. Print the report and stop. The user reviews the file before anything records it.

```
Test cases: specs/testcases/AO-439.md
- 9 behaviors: 2 fully covered by automated tests, 7 need test cases
- 5 test cases (web 5): 2 video, 3 screenshots
- Inputs: AO-439 ticket text from the user, diff vs DEV
- Asked: 1 question (daily limit: 5 a day, from the user)
- Code issues seen: "Send" is not disabled while the request runs (`TransferForm.tsx:58`)
```

If `.gitignore` does not ignore `.evidence/`, add a line to the report telling the user to add it. Do not edit `.gitignore`.

## Proof

Each case says how its result will be shown, so the recording follows a plan instead of guessing.

- **🎥 video** when a check depends on time or order: a loading or pending state, an animation, a transition, a countdown or timer, a toast that disappears, or a flow across several screens where the order matters. The ★ case is always video.
- **📷 screenshots** when every check is a state that one still frame can show: a message, a disabled button, a value on screen. The recording takes one screenshot per state a check names.

Write the reason in a few words, so a reviewer can disagree with it.

## Case file format

Tools read this file by these section names, field names and table columns, so keep them stable.

The Test Cases table has one row per case. The case title opens a `<details>` block that is collapsed by default, so the whole list fits on one screen and each row expands in place. most Markdown previews render it.

```markdown
# AO-439 - Crypto transfer

Source: AO-439 ticket text from the user, diff `feat/transfer/AO-439-crypto-transfer` vs `DEV`

## Setup

- App: web DEV, http://localhost:3000/transfer
- Account: tier 2 user (QA account "tier2-trader" in 1Password)
- Data: at least 50 USDT, one verified and one unverified address book entry
- Flags: `NEXT_PUBLIC_TRANSFER_V2=true` in `.env.local`

## Test Cases

<table>
<tr><th>ID</th><th>Case</th><th>Web</th><th>Proof</th></tr>
<tr><td>TC-3</td><td><details><summary>★ Send USDT to a verified address</summary>

- Behaviors: B-3, B-4
- Proof: video, because "Send" shows a spinner only while the request runs
- Steps:
  1. Pick the verified address from the address book
  2. Enter `10` in "Amount" and click "Send"
- Checks:
  1. The fee line shows "Network fee 1 USDT" before "Send" is clicked
  2. "Send" shows a spinner while the request runs
  3. The success screen shows "Sent 10 USDT"

</details></td><td>⏳ not run</td><td>🎥</td></tr>
<tr><td>TC-1</td><td><details><summary>Unverified address blocks the transfer</summary>

- Behaviors: B-2
- Proof: screenshots, because both checks are visible in one frame
- Preconditions: on the transfer form, USDT on TRON selected
- Steps:
  1. Pick the unverified address from the address book
  2. Enter `10` in "Amount"
- Checks:
  1. "Verify this address first" shows under the address
  2. "Send" is disabled

</details></td><td>⏳ not run</td><td>📷</td></tr>
</table>

## Behaviors

| ID  | Behavior                                                                              | Sources                                      | Coverage                                                         | Test |
| --- | ------------------------------------------------------------------------------------- | -------------------------------------------- | ---------------------------------------------------------------- | ---- |
| B-1 | The network picker lists only networks the selected coin supports                     | AC-1; `src/transfer/NetworkPicker.tsx:18-30` | full: `NetworkPicker.test.tsx` › "shows only supported networks" | —    |
| B-2 | A transfer to an unverified address shows "Verify this address first" and blocks Send | AC-2; `src/transfer/TransferForm.tsx:44`     | partial: `isVerified.test.ts` checks the rule, not the screen    | TC-1 |
```

Keep the blank line after each `<summary>` line and before each `</details>`, and do not indent the lines between them. Without that, the Markdown inside the row shows as raw text.

Rules for the table:

- **Columns:** `ID`, `Case`, one column per platform that any case uses (`Web`, `iOS`, `Android`), then `Proof`.
- **Platform cells:** `⏳ not run`, `✅ pass`, `❌ fail`, `⚠️ outdated`, `🚫 removed`, or `—` when the case does not run on that platform. The cells are the only place a result lives. A `.ios.tsx` or `.android.tsx` file, or a `Platform.OS` branch, limits a case to that platform.
- **Proof cell:** `🎥` or `📷`, matching the `Proof:` line.
- **Row order:** current cases first, the ★ case at the top and the rest by ID; then cases with a `⚠️ outdated` cell; then cases where every cell is `🚫 removed`. A case that no longer matches the requirement moves to the bottom, with its ID unchanged, even when it is the ★ case.

Rules for the fields inside a row:

- **Setup** lists only what every case needs. Leave out a line that does not apply.
- **Sources:** `AC-N`, `Req "<quote>"`, `Answer "<quote>"` or `path:line`. Use `AC-N` only when the requirement itself numbers the rule that way; a code-only behavior numbered as an AC looks like something the requirement asked for.
- **Steps:** short, in order, with real labels and values from the code (`Tap "Send"`, `Enter 0.000001`).
- **Checks:** numbered. Each one is text or an element that appears or disappears, so a check on the element tree or the DOM can prove it.
- **Preconditions:** optional, only when a case needs more than Setup.
- **Behaviors table:** the same order rule. A behavior the requirement no longer has gets `removed: <reason>` in its Test column and moves to the bottom.

### Re-runs

Recorded cases have one result line per platform inside the row. They are history:

```markdown
- iOS: Recording `TC-4/TC-4-ios.mp4` · Note: Lockout text showed 15:00 and counted down.
- Android: Screenshots `TC-4/TC-4-android-1-lockout.png` · Note: Resend button stayed visible.
```

- Leave unchanged cases alone.
- A case whose steps or checks change: add one line `- Outdated: <what changed>`, and every cell with a result becomes `⚠️ outdated`. Keep the result lines. The row moves to the outdated group.
- A platform added to a case: its cell becomes `⏳ not run`. Add the column if no case had that platform; other rows get `—` there.
- A platform dropped from a case: its cell becomes `🚫 removed`, and the row gets `- <platform> removed: <reason>`.
- A case that is no longer valid: every cell becomes `🚫 removed`, the row gets `- Removed: <reason>`, and it moves to the bottom.
- A file in the old layout (one `### TC-n` heading per case): convert it to the table. Keep every ID, title, step and expected line (as Checks). A `Status` becomes that platform's cell; `Recording` and `Note` become the result line; `Mode` lines are dropped.
- A file without a Behaviors table gets one, and each case gets a `- Behaviors:` line.
