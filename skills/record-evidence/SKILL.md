---
name: record-evidence
description: Runs the cases of a test case file against the real app and saves proof per case under .evidence/ (a video plus a note), then writes each result back into the case file. Works for web apps (Chrome DevTools MCP with screencast) and for the iOS simulator and Android emulators or devices (argent MCP). Reads any case file format (Markdown, tables, Gherkin or CSV). Use whenever the user wants recorded evidence, videos, screenshots or proof per test case for an MR or QA, for example "record the TC cases for AO-702 on ios", "record evidence for the transfer form on web", or "re-record the failed cases on android". Needs a case file the user has seen; it never writes test cases.
argument-hint: "<case-file> [on <web|ios|android>] [IDs...]"
---

# Record Evidence

Runs each picked case of a case file on one target. For each case it saves a recording and one note, then writes the result into the case file. A recording is the evidence. When no recording can be made, the run stops.

## Invocation

- `<case-file>`: from the arguments, or the case file named in the conversation. With no case file, stop and ask for one. This skill never writes cases.
- `on <target>`: optional, one of `web`, `ios`, `android`. When missing and every picked case has one target, use it. When the cases cover several targets, ask which one. One target per run; say in the report how to run the others.
- `IDs...`: optional. With IDs, record exactly those cases. Without IDs, see "Pick cases" below.

Run only on a case file the user has seen: they named it, or they reviewed it in this conversation. If the file was written in this conversation and not reviewed yet, stop and ask for that review first. After the one question in Phase 3, the skill asks nothing.

## Reading a case file

Case files come in many formats: Markdown with one heading per case, a Markdown table, Gherkin `.feature` files, CSV. Map each case to these fields by meaning, not by exact name:

| Field         | Common names                                                                                        |
| ------------- | --------------------------------------------------------------------------------------------------- |
| ID            | the ID in the case heading or first column: `TC-3`, `SS1`, `LOGIN-02`                               |
| Target        | `Platform`, `Targets`, `Device`, `OS`, `Browser`. Missing means the targets the Setup names         |
| Preconditions | `Preconditions`, `Needs`, `Given`, `Background`. `after <ID>` means it starts where that case ended |
| Steps         | `Steps`, `When`, a numbered list                                                                    |
| Expected      | `Expected`, `Expect`, `Then`, `Expected result`                                                     |
| Server check  | `Server check`, `API check`, `Backend`. Optional                                                    |
| Setup         | a file-level section: `Setup`, `Prerequisites`, `Environment`                                       |
| Results       | `Mode`, `Status`, `Recording`, `Note` lines, or a per-target block (`- ios:`) holding them          |

A common layout: `### TC-n - title`, then `Platform`, `Preconditions`, `Steps`, `Expected`, and result lines after a recording. When a format has a field this table does not list, read it as a note for the tester.

**Key:** the file name without its extension (`specs/testcases/AO-702.md` → `AO-702`). When that name is generic (`cases`, `index`, `README`), use the folder name.

### Pick cases

Without IDs in the arguments, pick every case that:

- runs on the target, and
- is not marked removed, inactive, draft or deprecated, and
- has no `pass` result for the target yet. A `fail` or `outdated` result is recorded again.

Then sort out cases the agent cannot drive. A case **needs a person** when it is marked for one (`Driver: human`, `Mode: manual`), or its steps need something no tool here can do: real biometrics, a real SMS or email, a camera, a card reader, a store sandbox login. It is not run; it goes in the ledger as BLOCKED with "needs a person: <what it needs>".

Print the pick before the Phase 1 gate, so it shows even when a gate stops the run. One line per case in the file: `TC-3 web — picked`, or `TC-2 — skipped (already pass on web)`.

## Invariants

1. **Use the plugin's MCP servers only.** `argent` drives `ios` and `android` (`references/mobile.md`); `chrome-devtools-rec` drives `web` (`references/web.md`). Never fall back to `xcrun simctl`, `adb`, Playwright or another browser server: their recordings and checks differ, and the evidence would not match from run to run.
2. **Record only what the file says.** Never add, change, or skip steps. A step that cannot be done fails the case.
3. **The result comes from a check, not from the recording.** A case passes only when every expected line was found in the element tree or the DOM snapshot. Reading a screenshot by eye is not a check. A video of a broken screen is a fail.
4. **No secrets in evidence or in the case file.** Network logs, headers, cookies and device logs can hold tokens. Save URLs, methods and status codes; replace any secret with `<redacted>`. Never write a password anywhere.
5. **Server checks are not optional.** When a case has a server check, the note records its result. If it cannot run, the note says so and the case is not VERIFIED.
6. **Never commit**, and never edit `.gitignore` without asking.
7. **Stop what you start.** Every recording is stopped, even when a step fails. Pages, the Chrome window, simulators, emulators and servers this run started are closed at the end; ones that were already running are left alone.

## Phases

Each phase ends with a gate. A failed gate stops the run and says which gate failed and how to fix it.

### Phase 1 — Read

1. Read the case file and map its cases (see "Reading a case file").
2. Pick the cases and print the pick.
3. The evidence folder is `.evidence/<KEY>/`. Each case gets `.evidence/<KEY>/<ID>/`.

**Gate:**

- every case has an ID. If not, stop: ask the user to add IDs. Folders and results are matched by ID.
- at least one case is picked, and every picked case has steps and an expected result.
- `git check-ignore -q .evidence/<KEY>/<ID>/x` exits 0 for a picked ID, so evidence never reaches git. If it does not, stop and ask the user to add `.evidence/` to `.gitignore`.

### Phase 2 — Tools

1. Read `references/mobile.md` for `ios` and `android`, or `references/web.md` for `web`.
2. Check that the server's tools are in the session: `list-devices` for argent, `new_page` for chrome-devtools-rec. Pick the device or open the page.
3. Make a test recording of about 2 seconds to `.evidence/<KEY>/probe.mp4` with the reference file's Video tools. Confirm the file exists and is not empty, then delete it. A connected server can still fail to record, for example when ffmpeg is missing, and both servers need it.

**Gate:** the server for the target answers and the test recording worked. If either fails, stop before any case runs. A run without video gives no evidence, so do not fall back to screenshots. Tell the user what failed and how to fix it: enable the plugin that ships these servers and run `/mcp` to see why a server did not start, or install ffmpeg (`brew install ffmpeg`) and restart the session.

### Phase 3 — Prepare

1. Read every Setup line and the preconditions of every picked case. Sort each item:
   - **Agent items:** a start command (dev server, mock server, seed script), a test account the file or the project's `CLAUDE.md` / `AGENTS.md` names, and app state the agent can reach with the target's tools (signed out, app data cleared, reinstalled, a URL).
   - **Person items:** anything marked `ask the user` or `TODO`, a password the file does not hold, and state set outside the app, such as a remote config flag or a store sandbox account.
2. Ask for all person items in one message and wait. Never guess a value. For a mobile password, ask the user to add it to an argent secrets file, never to send it (see `references/mobile.md`).
3. Start the app and do the agent items as written.

**Gate:** every person item is answered, and the app is running.

### Phase 4 — Record (per case)

Follow the reference file for each step:

1. Put the app in the state the preconditions name, and confirm it with a check. A state that cannot be reached or confirmed makes the case BLOCKED; never record from the wrong start.
2. Start the recording.
3. Do the steps in order.
4. Check each expected line. Note which lines held.
5. Stop the recording and confirm the file is in the case folder and not empty. If it is missing or empty, the recording tool broke: the case is BLOCKED, every case not yet run is NOT-RUN, and the run stops.
   Then run `bash scripts/fit-video.sh <video>` from this skill's folder. GitLab/Github provider rejects uploads over 10 MB, so every video must be 10 MB or less. The script shrinks a video over 10 MB in place and leaves the others alone. Exit 2 means it is still too big at the smallest step: keep the case result, say so in the note, and give it as the reason in the ledger.
6. Take screenshots only when the user asked for them.
7. Run the server check, if any.
8. Write the note (template below).

Case folder, every name starting with `<ID>-<target>`:

```text
.evidence/<KEY>/<ID>/
  <ID>-<target>.mp4               the video
  <ID>-<target>-<n>-<state>.png   only when the user asks
  <ID>-<target>-server.txt        only when there is a server check
  <ID>-<target>.md                the note
```

GitLab and GitHub name an uploaded file by its file name, and that name is how each link in the MR is matched to its case.

A failed case keeps its recording and gets `Result: fail`, with the failed step or expected line in "What I saw". Go on to the next case, unless its preconditions name the failed case; then stop and say why.

Server checks: queries against data are read-only. A check that must change a setting (for example a DB profiler) turns it back off right after the case. Confirm which backend the build points at before the first query.

### Phase 5 — Write back and report

**Write back.** For each recorded case, write its result into the case file with these result lines:

- A case with one target: plain lines at the end of the case.
- A case with several targets: one block per target, because each target passes or fails on its own.

```markdown
- Platform: ios, android
- Steps: ...
- Expected: ...
- ios:
  - Mode: agent
  - Status: pass
  - Recording: TC-4/TC-4-ios.mp4
  - Note: Lockout text showed 15:00 and counted down.
```

- `Status` is `pass` or `fail`. `Recording` is the video path relative to `.evidence/<KEY>/`. `Note` is one line.
- Replace the target's old result lines or block. Leave other targets alone.
- When no target of the case is still `outdated`, delete the case's `- Outdated:` line.
- BLOCKED and NOT-RUN cases get nothing.
- Change nothing else in the file: no steps, no wording, no IDs.
- A file that is not Markdown with one block per case (CSV, `.feature`, a table) is not edited. Say in the report that the notes are the only record.

**Report.** Print in chat:

1. `VERIFIED X of N; NOT VERIFIED N−X (reason)` first.
2. A ledger, one row per picked case:

   ```text
   case | status | video | reason
   ```

   Status is one of VERIFIED, FAILED, BLOCKED, NOT-RUN. The reason names a server check that did not run.

3. The evidence folder, the tools used, and whether the case file was updated.
4. One line: the notes are ready to become the MR evidence block.

Then clean up as the reference file says.

## Note template

```markdown
# TC-4 — iOS — Lockout after 3 resends

- Result: pass / fail
- Driven by: agent (argent)
- Build: dev · Device: iPhone 16 (sim)
- Account: <test account name, never a password>
- Date: YYYY-MM-DD
- Video: TC-4-ios.mp4

## Checks

- [x] "Too many attempts. Try again in 15:00" shows
- [x] "Resend code" is hidden

## Server check

<request method + URL + status, no headers>. <query result>.

## What I saw

Only on fail: steps, expected, actual.
```

Leave out `## Server check` when the case has none. For web, `Device` is the browser and its viewport.
